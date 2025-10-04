//
//  ModelConfig.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import Foundation

/// Configuration for a language model that can be downloaded and run locally
struct ModelConfig: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let huggingFaceRepo: String
    let fileSizeMB: Int
    let contextLength: Int
    let description: String
    let recommendedFor: [String]

    /// All available pre-configured models
    static let availableModels: [ModelConfig] = [
        .llama32_1B_4bit,
        .llama32_3B_4bit,
        .phi3_mini_4bit,
        .qwen25_3B_4bit
    ]

    /// Llama 3.2 1B Instruct (4-bit quantized) - Recommended starter model
    static let llama32_1B_4bit = ModelConfig(
        id: "llama-3.2-1b-instruct-4bit",
        name: "llama-3.2-1b-instruct-4bit",
        displayName: "Llama 3.2 1B Instruct (4-bit)",
        huggingFaceRepo: "mlx-community/Llama-3.2-1B-Instruct-4bit",
        fileSizeMB: 600,
        contextLength: 2048,
        description: "Smallest and fastest model. Great for basic conversations and testing.",
        recommendedFor: ["Quick responses", "Limited RAM devices", "Testing"]
    )

    /// Llama 3.2 3B Instruct (4-bit quantized)
    static let llama32_3B_4bit = ModelConfig(
        id: "llama-3.2-3b-instruct-4bit",
        name: "llama-3.2-3b-instruct-4bit",
        displayName: "Llama 3.2 3B Instruct (4-bit)",
        huggingFaceRepo: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        fileSizeMB: 1800,
        contextLength: 2048,
        description: "Better quality responses with slightly slower inference. Recommended for most users.",
        recommendedFor: ["Balanced quality", "General use", "iPhone 15 Pro+"]
    )

    /// Phi-3 Mini (4-bit quantized)
    static let phi3_mini_4bit = ModelConfig(
        id: "phi-3-mini-4bit",
        name: "phi-3-mini-4bit",
        displayName: "Phi-3 Mini (4-bit)",
        huggingFaceRepo: "mlx-community/Phi-3-mini-4bit",
        fileSizeMB: 2100,
        contextLength: 4096,
        description: "Microsoft's compact model with longer context. Good for code and reasoning.",
        recommendedFor: ["Coding assistance", "Longer context", "Reasoning tasks"]
    )

    /// Qwen 2.5 3B (4-bit quantized)
    static let qwen25_3B_4bit = ModelConfig(
        id: "qwen-2.5-3b-4bit",
        name: "qwen-2.5-3b-4bit",
        displayName: "Qwen 2.5 3B (4-bit)",
        huggingFaceRepo: "mlx-community/Qwen2.5-3B-Instruct-4bit",
        fileSizeMB: 1900,
        contextLength: 4096,
        description: "Multilingual model with strong performance. Supports many languages.",
        recommendedFor: ["Multilingual", "Strong reasoning", "General purpose"]
    )

    /// Get the local file URL where the model should be stored
    func localURL(in baseDirectory: URL) -> URL {
        return baseDirectory.appendingPathComponent(id)
    }

    /// Check if the model is already downloaded
    func isDownloaded(in baseDirectory: URL) -> Bool {
        let modelURL = localURL(in: baseDirectory)
        let configPath = modelURL.appendingPathComponent("config.json")
        let weightsPath = modelURL.appendingPathComponent("model.safetensors")

        return FileManager.default.fileExists(atPath: configPath.path) &&
               FileManager.default.fileExists(atPath: weightsPath.path)
    }
}

/// Model download state
enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case error(String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}
