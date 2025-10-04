//
//  InferenceEngine.swift
//  LocalLabs
//
//  MLX-based local inference engine for iPhone
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Hub

/// Manages MLX model inference with streaming support - fully local on iPhone
@MainActor
@Observable
class InferenceEngine {
    /// The currently loaded model container
    private var modelContainer: ModelContainer?

    /// The model configuration being used
    private(set) var currentModelConfig: ModelConfig?

    /// Whether a model is currently loaded
    private(set) var isModelLoaded: Bool = false

    /// Current inference state
    private(set) var isGenerating: Bool = false

    /// Generation statistics
    private(set) var lastGenerationStats: GenerationStats?

    /// Maximum tokens to generate (configurable for different use cases)
    var maxTokens: Int = 512

    /// Temperature for sampling (lower = more focused, higher = more creative)
    var temperature: Float = 0.7

    /// Top-p sampling parameter (nucleus sampling threshold)
    var topP: Float = 0.9

    init() {}

    /// Load a model from local disk (for local iPhone inference)
    /// - Parameters:
    ///   - modelPath: URL to the model directory on device
    ///   - config: Model configuration
    func loadModel(from modelPath: URL, config: ModelConfig) async throws {
        print("🔄 Loading model locally: \(config.displayName)")
        print("📂 Model path: \(modelPath.path)")

        do {
            // Unload any existing model first
            unloadModel()

            // Set GPU cache limit dynamically based on available memory
            let cacheLimit = calculateOptimalGPUCache()
            MLX.GPU.set(cacheLimit: cacheLimit)
            print("🎮 GPU cache limit set to: \(cacheLimit / 1024 / 1024)MB")

            // Create ModelConfiguration pointing to local directory
            let modelConfiguration = ModelConfiguration(
                directory: modelPath
            )

            // Load the model container
            modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) { progress in
                print("📥 Loading progress: \(Int(progress.fractionCompleted * 100))%")
            }

            currentModelConfig = config
            isModelLoaded = true

            print("✅ Model loaded successfully: \(config.displayName)")
            print("💾 Memory usage: ~\(config.fileSizeMB)MB")

        } catch {
            isModelLoaded = false
            currentModelConfig = nil
            modelContainer = nil
            print("❌ Failed to load model: \(error.localizedDescription)")
            throw InferenceError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Unload the current model to free memory
    func unloadModel() {
        modelContainer = nil
        currentModelConfig = nil
        isModelLoaded = false
        print("🗑️ Model unloaded")
    }

    /// Generate a response with conversation history - all local on iPhone
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - onToken: Callback for each generated token
    /// - Returns: The complete generated text
    func generateWithHistory(
        messages: [Message],
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard let container = modelContainer else {
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
            // Convert messages to Chat.Message format
            var chatMessages: [Chat.Message] = [
                .system("You are a helpful AI assistant running locally on an iPhone.")
            ]

            for message in messages {
                if message.role == .user {
                    chatMessages.append(.user(message.content))
                } else if message.role == .assistant {
                    chatMessages.append(.assistant(message.content))
                }
            }

            // Prepare the user input with chat format
            let userInput = UserInput(chat: chatMessages)

            // Random seed for generation variety
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            // Capture generation parameters before entering perform closure
            let tempValue = self.temperature
            let topPValue = self.topP
            let maxTokensValue = self.maxTokens

            var tokenCount = 0

            // Use perform to access the model context
            try await container.perform { (context: ModelContext) -> Void in
                // Prepare the input
                let lmInput = try await context.processor.prepare(input: userInput)

                // Generate with parameters
                let generateParams = GenerateParameters(
                    temperature: tempValue,
                    topP: topPValue
                )

                // Create the generation stream
                let stream = try MLXLMCommon.generate(
                    input: lmInput,
                    parameters: generateParams,
                    context: context
                )

                // Process the stream
                for try await generation in stream {
                    if let chunk = generation.chunk {
                        fullResponse += chunk
                        tokenCount += 1

                        // Call the token callback
                        onToken(chunk)
                    }

                    // Update stats if available
                    if let info = generation.info {
                        Task { @MainActor in
                            self.lastGenerationStats = GenerationStats(
                                tokensGenerated: tokenCount,
                                timeElapsed: Date().timeIntervalSince(startTime),
                                tokensPerSecond: info.tokensPerSecond
                            )
                        }
                    }

                    // Check for max tokens
                    if tokenCount >= maxTokensValue {
                        print("⚠️ Max tokens reached: \(maxTokensValue)")
                        break
                    }
                }
            }

            // Calculate final statistics
            let duration = Date().timeIntervalSince(startTime)
            if lastGenerationStats == nil {
                lastGenerationStats = GenerationStats(
                    tokensGenerated: tokenCount,
                    timeElapsed: duration,
                    tokensPerSecond: Double(tokenCount) / duration
                )
            }

            print("📊 Generation complete: \(tokenCount) tokens in \(String(format: "%.2f", duration))s (\(String(format: "%.1f", lastGenerationStats!.tokensPerSecond)) tok/s)")

            return fullResponse

        } catch {
            print("❌ Generation failed: \(error.localizedDescription)")
            throw InferenceError.generationFailed(error.localizedDescription)
        }
    }

    /// Generate a response to a prompt with streaming - all local on iPhone
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - onToken: Callback for each generated token
    /// - Returns: The complete generated text
    func generate(
        prompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard let container = modelContainer else {
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
            // Prepare the user input with chat format
            let userInput = UserInput(
                chat: [
                    .system("You are a helpful AI assistant running locally on an iPhone."),
                    .user(prompt)
                ]
            )

            // Random seed for generation variety
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            // Capture generation parameters before entering perform closure
            let tempValue = self.temperature
            let topPValue = self.topP
            let maxTokensValue = self.maxTokens

            var tokenCount = 0

            // Use perform to access the model context
            try await container.perform { (context: ModelContext) -> Void in
                // Prepare the input
                let lmInput = try await context.processor.prepare(input: userInput)

                // Generate with parameters
                let generateParams = GenerateParameters(
                    temperature: tempValue,
                    topP: topPValue
                )

                // Create the generation stream
                let stream = try MLXLMCommon.generate(
                    input: lmInput,
                    parameters: generateParams,
                    context: context
                )

                // Process the stream
                for try await generation in stream {
                    if let chunk = generation.chunk {
                        fullResponse += chunk
                        tokenCount += 1

                        // Call the token callback
                        Task { @MainActor in
                            onToken(chunk)
                        }
                    }

                    // Update stats if available
                    if let info = generation.info {
                        Task { @MainActor in
                            self.lastGenerationStats = GenerationStats(
                                tokensGenerated: tokenCount,
                                timeElapsed: Date().timeIntervalSince(startTime),
                                tokensPerSecond: info.tokensPerSecond
                            )
                        }
                    }

                    // Check for max tokens
                    if tokenCount >= maxTokensValue {
                        print("⚠️ Max tokens reached: \(maxTokensValue)")
                        break
                    }
                }
            }

            // Calculate final statistics
            let duration = Date().timeIntervalSince(startTime)
            if lastGenerationStats == nil {
                lastGenerationStats = GenerationStats(
                    tokensGenerated: tokenCount,
                    timeElapsed: duration,
                    tokensPerSecond: Double(tokenCount) / duration
                )
            }

            print("📊 Generation complete: \(tokenCount) tokens in \(String(format: "%.2f", duration))s (\(String(format: "%.1f", lastGenerationStats!.tokensPerSecond)) tok/s)")

            return fullResponse

        } catch {
            print("❌ Generation failed: \(error.localizedDescription)")
            throw InferenceError.generationFailed(error.localizedDescription)
        }
    }

    /// Calculate optimal GPU cache limit based on device memory
    /// - Returns: Cache limit in bytes
    private func calculateOptimalGPUCache() -> Int {
        // Get physical memory of the device
        var size: UInt64 = 0
        var sizeLen = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &sizeLen, nil, 0)

        let totalMemoryMB = Int(size / 1024 / 1024)

        // Allocate GPU cache based on total device memory
        // Conservative approach: use ~10-15% of total memory for GPU cache
        let cacheSizeMB: Int
        if totalMemoryMB >= 6000 {
            // 6GB+ devices (iPhone 13 Pro and newer): use 1GB cache
            cacheSizeMB = 1024
        } else if totalMemoryMB >= 4000 {
            // 4GB+ devices (iPhone 12 and newer): use 512MB cache
            cacheSizeMB = 512
        } else if totalMemoryMB >= 3000 {
            // 3GB+ devices (iPhone XS and newer): use 256MB cache
            cacheSizeMB = 256
        } else {
            // Older devices: use conservative 128MB cache
            cacheSizeMB = 128
        }

        return cacheSizeMB * 1024 * 1024
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
