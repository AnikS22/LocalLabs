//
//  ChatViewModel.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import Foundation
import SwiftData

/// ViewModel for managing chat UI state and interactions
@MainActor
@Observable
class ChatViewModel {
    /// The chat service
    private let chatService: ChatService

    /// Current user input
    var userInput: String = ""

    /// Whether a message is currently being sent
    var isSending: Bool = false

    /// Current error message to display
    var errorMessage: String?

    /// Whether to show error alert
    var showError: Bool = false

    /// Current streaming response (for displaying partial assistant responses)
    var streamingResponse: String = ""

    /// Whether currently streaming a response
    var isStreaming: Bool = false

    /// Current conversation
    var conversation: Conversation?

    /// Generation statistics
    var lastStats: GenerationStats? {
        chatService.lastStats
    }

    init(chatService: ChatService) {
        self.chatService = chatService
    }

    /// Convenience initializer using shared service
    init() {
        self.chatService = ChatService.shared
    }

    /// Send the current user input as a message
    func sendMessage() {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let messageToSend = userInput
        userInput = "" // Clear input immediately
        streamingResponse = ""

        Task {
            isSending = true
            isStreaming = true

            do {
                // Ensure we have a conversation
                if conversation == nil || chatService.currentConversation == nil {
                    conversation = try chatService.startNewConversation()
                }

                // Send message with streaming
                try await chatService.sendMessage(messageToSend) { token in
                    Task { @MainActor in
                        self.streamingResponse += token
                    }
                }

                // Clear streaming response after completion
                streamingResponse = ""

            } catch {
                handleError(error)
            }

            isSending = false
            isStreaming = false
        }
    }

    /// Load a specific conversation
    /// - Parameter conversation: The conversation to load
    func loadConversation(_ conversation: Conversation) {
        self.conversation = conversation
        chatService.loadConversation(conversation)
    }

    /// Start a new conversation
    func startNewConversation() {
        do {
            conversation = try chatService.startNewConversation()
        } catch {
            handleError(error)
        }
    }

    /// Delete the current conversation
    func deleteCurrentConversation() {
        guard let conversation = conversation else { return }

        do {
            try chatService.deleteConversation(conversation)
            self.conversation = nil
        } catch {
            handleError(error)
        }
    }

    /// Handle errors by showing them to the user
    /// - Parameter error: The error to handle
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        print("❌ Error: \(error.localizedDescription)")
    }

    /// Get formatted timestamp for a message
    /// - Parameter message: The message
    /// - Returns: Formatted time string
    func formattedTime(for message: Message) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }

    /// Check if the chat is ready
    var isReady: Bool {
        chatService.isReady
    }

    /// Get current model name
    var currentModelName: String? {
        chatService.currentModel?.displayName
    }
}
