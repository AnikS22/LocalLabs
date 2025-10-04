//
//  ModelManager.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import Foundation

/// Manages downloading, caching, and loading of MLX models from HuggingFace
@MainActor
@Observable
class ModelManager {
    /// Singleton instance
    static let shared = ModelManager()

    /// Base directory for storing models
    private let modelsDirectory: URL

    /// Current download states for each model
    var downloadStates: [String: ModelDownloadState] = [:]

    /// Currently loaded model configuration
    var loadedModel: ModelConfig?

    /// Active download tasks
    private var downloadTasks: [String: Task<Void, Error>] = [:]

    private init() {
        // Store models in app's Documents/Models directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.modelsDirectory = documentsPath.appendingPathComponent("Models")

        // Create models directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Initialize download states
        updateDownloadStates()
    }

    /// Update download states for all available models
    func updateDownloadStates() {
        for model in ModelConfig.availableModels {
            if model.isDownloaded(in: modelsDirectory) {
                downloadStates[model.id] = .downloaded
            } else {
                downloadStates[model.id] = .notDownloaded
            }
        }
    }

    /// Download a model from HuggingFace
    /// - Parameter model: The model configuration to download
    func downloadModel(_ model: ModelConfig) async throws {
        // Check if already downloading
        guard downloadStates[model.id] != .downloading(progress: 0) else {
            return
        }

        // Set initial downloading state
        downloadStates[model.id] = .downloading(progress: 0.0)

        do {
            let modelURL = model.localURL(in: modelsDirectory)

            // Create model directory
            try FileManager.default.createDirectory(at: modelURL, withIntermediateDirectories: true)

            // Files to download from HuggingFace (based on typical MLX model structure)
            let filesToDownload = [
                "config.json",
                "model.safetensors",
                "tokenizer.json",
                "tokenizer.model",
                "tokenizer_config.json",
                "special_tokens_map.json"
            ]

            var downloadedFiles = 0
            let totalFiles = filesToDownload.count

            // Download each file
            for filename in filesToDownload {
                let urlString = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(filename)"

                guard let url = URL(string: urlString) else {
                    print("⚠️  Invalid URL for \(filename), skipping")
                    continue
                }

                let destinationURL = modelURL.appendingPathComponent(filename)

                // Download file
                do {
                    let (tempURL, _) = try await URLSession.shared.download(from: url)
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    downloadedFiles += 1
                    let progress = Double(downloadedFiles) / Double(totalFiles)
                    downloadStates[model.id] = .downloading(progress: progress)

                    print("✅ Downloaded \(filename)")
                } catch {
                    // Some files might not exist (e.g., tokenizer.model vs tokenizer.json)
                    // Only fail if critical files are missing
                    if filename == "config.json" || filename == "model.safetensors" {
                        throw error
                    } else {
                        print("⚠️  Optional file \(filename) not found, skipping")
                    }
                }
            }

            // Verify critical files exist
            let configPath = modelURL.appendingPathComponent("config.json")
            let weightsPath = modelURL.appendingPathComponent("model.safetensors")

            guard FileManager.default.fileExists(atPath: configPath.path) else {
                throw ModelManagerError.missingFile("config.json")
            }

            guard FileManager.default.fileExists(atPath: weightsPath.path) else {
                throw ModelManagerError.missingFile("model.safetensors")
            }

            // Mark as downloaded
            downloadStates[model.id] = .downloaded
            print("✅ Model downloaded successfully: \(model.displayName)")

        } catch {
            downloadStates[model.id] = .error(error.localizedDescription)
            print("❌ Model download failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Cancel an ongoing download
    /// - Parameter model: The model to cancel downloading
    func cancelDownload(_ model: ModelConfig) {
        downloadTasks[model.id]?.cancel()
        downloadTasks.removeValue(forKey: model.id)
        downloadStates[model.id] = .notDownloaded
    }

    /// Delete a downloaded model to free up space
    /// - Parameter model: The model to delete
    func deleteModel(_ model: ModelConfig) throws {
        let modelURL = model.localURL(in: modelsDirectory)
        try FileManager.default.removeItem(at: modelURL)
        downloadStates[model.id] = .notDownloaded

        if loadedModel?.id == model.id {
            loadedModel = nil
        }
    }

    /// Get the local path for a downloaded model
    /// - Parameter model: The model configuration
    /// - Returns: URL to the model directory, or nil if not downloaded
    func getModelPath(_ model: ModelConfig) -> URL? {
        guard model.isDownloaded(in: modelsDirectory) else {
            return nil
        }
        return model.localURL(in: modelsDirectory)
    }

    /// Calculate total disk space used by all downloaded models
    func getTotalModelSize() -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = FileManager.default.enumerator(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    /// Format bytes to human-readable string
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Errors

enum ModelManagerError: LocalizedError {
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let filename):
            return "Required model file not found: \(filename)"
        }
    }
}
