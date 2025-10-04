//
//  InferenceEngine.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import Foundation
import MLX
import MLXLLM
import MLXRandom
import Tokenizers

/// Manages MLX model inference with streaming support
@MainActor
@Observable
class InferenceEngine {
    /// The currently loaded LLM model container
    private var llmModel: LLMModel?

    /// The model configuration being used
    private(set) var currentModelConfig: ModelConfig?

    /// Whether a model is currently loaded
    private(set) var isModelLoaded: Bool = false

    /// Current inference state
    private(set) var isGenerating: Bool = false

    /// Generation statistics
    private(set) var lastGenerationStats: GenerationStats?

    /// Maximum tokens to generate
    private let maxTokens: Int = 512

    /// Temperature for sampling (lower = more focused, higher = more creative)
    private let temperature: Float = 0.7

    /// Top-p sampling parameter
    private let topP: Float = 0.9

    init() {}

    /// Load a model from disk
    /// - Parameters:
    ///   - modelPath: URL to the model directory
    ///   - config: Model configuration
    func loadModel(from modelPath: URL, config: ModelConfig) async throws {
        print("🔄 Loading model: \(config.displayName)")
        print("📂 Model path: \(modelPath.path)")

        do {
            // Unload any existing model first
            unloadModel()

            // Load the model using MLXLLM
            // The LLMModel.load() method expects a path to a directory containing:
            // - config.json
            // - weights.safetensors (or model.safetensors)
            // - tokenizer.json
            let modelConfiguration = ModelConfiguration.directory(modelPath)

            // Load the model with Metal GPU acceleration
            llmModel = try await LLMModel.load(hub: modelConfiguration)

            currentModelConfig = config
            isModelLoaded = true

            print("✅ Model loaded successfully: \(config.displayName)")
            print("💾 Memory usage: ~\(config.fileSizeMB)MB")

        } catch {
            isModelLoaded = false
            currentModelConfig = nil
            llmModel = nil
            print("❌ Failed to load model: \(error.localizedDescription)")
            throw InferenceError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Unload the current model to free memory
    func unloadModel() {
        llmModel = nil
        currentModelConfig = nil
        isModelLoaded = false
        print("🗑️ Model unloaded")
    }

    /// Generate a response to a prompt with streaming
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - onToken: Callback for each generated token
    /// - Returns: The complete generated text
    func generate(
        prompt: String,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        guard let model = llmModel else {
            throw InferenceError.modelNotLoaded
        }

        guard !isGenerating else {
            throw InferenceError.alreadyGenerating
        }

        isGenerating = true
        defer { isGenerating = false }

        var fullResponse = ""
        let startTime = Date()

        do {
            // Prepare the prompt with chat template
            let formattedPrompt = formatPrompt(prompt)

            // Create generation parameters
            let generateParameters = GenerateParameters(
                temperature: temperature,
                topP: topP
            )

            // Generate with streaming
            var tokenCount = 0
            let stream = try await model.generate(
                prompt: formattedPrompt,
                parameters: generateParameters,
                maxTokens: maxTokens
            )

            for try await token in stream {
                fullResponse += token.text
                tokenCount += 1
                onToken(token.text)

                // Check for context overflow
                if tokenCount >= maxTokens {
                    print("⚠️ Max tokens reached: \(maxTokens)")
                    break
                }
            }

            // Calculate statistics
            let duration = Date().timeIntervalSince(startTime)
            lastGenerationStats = GenerationStats(
                tokensGenerated: tokenCount,
                timeElapsed: duration,
                tokensPerSecond: Double(tokenCount) / duration
            )

            print("📊 Generation stats: \(tokenCount) tokens in \(String(format: "%.2f", duration))s (\(String(format: "%.1f", lastGenerationStats!.tokensPerSecond)) tok/s)")

            return fullResponse

        } catch {
            print("❌ Generation failed: \(error.localizedDescription)")
            throw InferenceError.generationFailed(error.localizedDescription)
        }
    }

    /// Format a user prompt with the appropriate chat template
    /// - Parameter userMessage: The user's message
    /// - Returns: Formatted prompt ready for the model
    private func formatPrompt(_ userMessage: String) -> String {
        // For Llama models, use the chat template format
        // Different models may require different templates
        guard let config = currentModelConfig else {
            return userMessage
        }

        if config.id.contains("llama") {
            // Llama 3.2 chat template
            return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>

            You are a helpful AI assistant running locally on an iPhone.<|eot_id|><|start_header_id|>user<|end_header_id|>

            \(userMessage)<|eot_id|><|start_header_id|>assistant<|end_header_id|>


            """
        } else if config.id.contains("phi") {
            // Phi-3 chat template
            return "<|system|>\nYou are a helpful AI assistant.<|end|>\n<|user|>\n\(userMessage)<|end|>\n<|assistant|>\n"
        } else if config.id.contains("qwen") {
            // Qwen chat template
            return "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n<|im_start|>user\n\(userMessage)<|im_end|>\n<|im_start|>assistant\n"
        }

        // Fallback for unknown models
        return userMessage
    }

    /// Format a conversation history into a prompt
    /// - Parameter messages: Array of messages in the conversation
    /// - Returns: Formatted prompt with full conversation
    func formatConversationPrompt(_ messages: [Message]) -> String {
        guard let config = currentModelConfig else {
            return messages.last?.content ?? ""
        }

        if config.id.contains("llama") {
            var prompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n"
            prompt += "You are a helpful AI assistant running locally on an iPhone.<|eot_id|>"

            for message in messages {
                if message.role == .user {
                    prompt += "<|start_header_id|>user<|end_header_id|>\n\n\(message.content)<|eot_id|>"
                } else if message.role == .assistant {
                    prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n\(message.content)<|eot_id|>"
                }
            }

            prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n"
            return prompt
        }

        // Fallback: just return the last user message
        return messages.last?.content ?? ""
    }

    /// Check available memory and warn if low
    func checkMemoryAvailability() -> MemoryStatus {
        // Get available memory
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            return .unknown
        }

        let usedMemoryMB = Int64(info.resident_size) / 1024 / 1024

        // Rough heuristics for iPhone memory warnings
        if usedMemoryMB > 2500 {
            return .critical
        } else if usedMemoryMB > 2000 {
            return .warning
        } else {
            return .ok
        }
    }
}

// MARK: - Supporting Types

/// Statistics from a generation run
struct GenerationStats {
    let tokensGenerated: Int
    let timeElapsed: TimeInterval
    let tokensPerSecond: Double
}

/// Memory status indicators
enum MemoryStatus {
    case ok
    case warning
    case critical
    case unknown

    var description: String {
        switch self {
        case .ok: return "Memory OK"
        case .warning: return "Memory usage high"
        case .critical: return "Memory critical"
        case .unknown: return "Unknown"
        }
    }
}

/// Inference-specific errors
enum InferenceError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case alreadyGenerating
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is currently loaded. Please load a model first."
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .alreadyGenerating:
            return "A generation is already in progress."
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        }
    }
}
