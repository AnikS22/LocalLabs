//
//  ChatService.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import Foundation
import SwiftData

/// High-level service that orchestrates model management, inference, and chat functionality
@MainActor
@Observable
class ChatService {
    /// Shared singleton instance
    static let shared = ChatService()

    /// Model manager for downloading and caching models
    let modelManager: ModelManager

    /// Inference engine for running models
    let inferenceEngine: InferenceEngine

    /// Current active conversation
    private(set) var currentConversation: Conversation?

    /// Swift Data model context for persistence
    private var modelContext: ModelContext?

    /// Whether the service is ready to chat
    var isReady: Bool {
        inferenceEngine.isModelLoaded
    }

    /// Current model being used
    var currentModel: ModelConfig? {
        inferenceEngine.currentModelConfig
    }

    private init() {
        self.modelManager = ModelManager.shared
        self.inferenceEngine = InferenceEngine()
    }

    /// Set the Swift Data model context
    /// - Parameter context: The model context to use for persistence
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Initialize the service with a specific model
    /// - Parameter model: The model to load
    func initialize(with model: ModelConfig) async throws {
        // Check if model is downloaded
        guard model.isDownloaded(in: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Models")) else {
            throw ChatServiceError.modelNotDownloaded
        }

        // Get model path
        guard let modelPath = modelManager.getModelPath(model) else {
            throw ChatServiceError.modelNotFound
        }

        // Load the model
        try await inferenceEngine.loadModel(from: modelPath, config: model)

        print("✅ ChatService initialized with \(model.displayName)")
    }

    /// Start a new conversation
    /// - Parameter title: Optional title for the conversation
    /// - Returns: The new conversation
    @discardableResult
    func startNewConversation(title: String? = nil) throws -> Conversation {
        guard let currentModel = currentModel else {
            throw ChatServiceError.noModelLoaded
        }

        let conversation = Conversation(
            title: title ?? "New Chat",
            modelName: currentModel.id
        )

        modelContext?.insert(conversation)
        try? modelContext?.save()

        currentConversation = conversation
        print("📝 Started new conversation: \(conversation.title)")

        return conversation
    }

    /// Load an existing conversation
    /// - Parameter conversation: The conversation to load
    func loadConversation(_ conversation: Conversation) {
        currentConversation = conversation
        print("📖 Loaded conversation: \(conversation.title)")
    }

    /// Send a message and get a response
    /// - Parameters:
    ///   - userMessage: The user's message text
    ///   - onToken: Callback for streaming tokens
    /// - Returns: The assistant's response message
    @discardableResult
    func sendMessage(
        _ userMessage: String,
        onToken: @escaping (String) -> Void = { _ in }
    ) async throws -> Message {
        guard let conversation = currentConversation else {
            throw ChatServiceError.noConversation
        }

        guard !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatServiceError.emptyMessage
        }

        // Check memory before generating
        let memoryStatus = inferenceEngine.checkMemoryAvailability()
        if memoryStatus == .critical {
            throw ChatServiceError.memoryPressure
        }

        // Create user message
        let userMsg = Message(content: userMessage, role: .user)
        userMsg.conversation = conversation
        conversation.messages.append(userMsg)
        modelContext?.insert(userMsg)

        // Get conversation history
        let allMessages = conversation.messages.sorted(by: { $0.timestamp < $1.timestamp })

        // Manage context window - keep only recent messages if context is too long
        let managedMessages = manageContextWindow(messages: allMessages)

        // Format prompt with conversation history
        let prompt = inferenceEngine.formatConversationPrompt(managedMessages)

        // Create assistant message placeholder
        let assistantMsg = Message(content: "", role: .assistant)
        assistantMsg.conversation = conversation
        conversation.messages.append(assistantMsg)
        modelContext?.insert(assistantMsg)

        var accumulatedResponse = ""

        // Generate response with streaming
        do {
            let response = try await inferenceEngine.generate(prompt: prompt) { token in
                accumulatedResponse += token
                assistantMsg.content = accumulatedResponse
                onToken(token)
            }

            // Update final response
            assistantMsg.content = response

            // Update conversation timestamp
            conversation.touch()

            // Auto-generate title if this is the first exchange
            if conversation.messages.count == 2 {
                conversation.title = generateTitle(from: userMessage)
            }

            // Save to database
            try? modelContext?.save()

            print("💬 Message exchange completed")
            return assistantMsg

        } catch {
            // Remove the failed assistant message
            if let index = conversation.messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                conversation.messages.remove(at: index)
            }
            modelContext?.delete(assistantMsg)

            print("❌ Failed to generate response: \(error.localizedDescription)")
            throw error
        }
    }

    /// Manage context window by keeping only recent messages
    /// - Parameter messages: All messages in the conversation
    /// - Returns: Messages that fit within the context window
    private func manageContextWindow(messages: [Message]) -> [Message] {
        guard let modelConfig = currentModel else {
            return messages
        }

        // Rough estimation: average 4 characters per token
        let maxChars = modelConfig.contextLength * 3 // Leave room for response

        var totalChars = 0
        var managedMessages: [Message] = []

        // Add messages from most recent to oldest until we hit the limit
        for message in messages.reversed() {
            totalChars += message.content.count
            if totalChars > maxChars {
                break
            }
            managedMessages.insert(message, at: 0)
        }

        // Always include at least the last user message
        if managedMessages.isEmpty && !messages.isEmpty {
            managedMessages = [messages.last!]
        }

        if managedMessages.count < messages.count {
            print("⚠️ Context trimmed: Using \(managedMessages.count)/\(messages.count) messages")
        }

        return managedMessages
    }

    /// Generate a title from the first user message
    /// - Parameter firstMessage: The first message in the conversation
    /// - Returns: A generated title
    private func generateTitle(from firstMessage: String) -> String {
        // Take first 5-6 words or first sentence
        let words = firstMessage.components(separatedBy: .whitespaces)
        let titleWords = words.prefix(6)
        var title = titleWords.joined(separator: " ")

        // Truncate if too long
        if title.count > 50 {
            title = String(title.prefix(47)) + "..."
        }

        return title.isEmpty ? "New Chat" : title
    }

    /// Delete a conversation
    /// - Parameter conversation: The conversation to delete
    func deleteConversation(_ conversation: Conversation) throws {
        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }

        modelContext?.delete(conversation)
        try? modelContext?.save()

        print("🗑️ Deleted conversation: \(conversation.title)")
    }

    /// Get statistics about the current inference
    var lastStats: GenerationStats? {
        inferenceEngine.lastGenerationStats
    }

    /// Unload the current model to free memory
    func unloadModel() {
        inferenceEngine.unloadModel()
        print("🔄 Model unloaded")
    }
}

// MARK: - Errors

enum ChatServiceError: LocalizedError {
    case noModelLoaded
    case modelNotDownloaded
    case modelNotFound
    case noConversation
    case emptyMessage
    case memoryPressure

    var errorDescription: String? {
        switch self {
        case .noModelLoaded:
            return "No model is currently loaded. Please select and load a model first."
        case .modelNotDownloaded:
            return "The selected model has not been downloaded yet. Please download it first."
        case .modelNotFound:
            return "The model files could not be found on disk."
        case .noConversation:
            return "No active conversation. Please start a new conversation first."
        case .emptyMessage:
            return "Cannot send an empty message."
        case .memoryPressure:
            return "Device memory is critically low. Please close other apps and try again."
        }
    }
}
