//
//  ModelSelectionView.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import SwiftUI
import SwiftData

/// View for selecting, downloading, and managing AI models
struct ModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var modelManager = ModelManager.shared
    @State private var chatService = ChatService.shared
    @State private var selectedModel: ModelConfig?
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: ModelConfig?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let currentModel = chatService.currentModel {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Currently using: \(currentModel.displayName)")
                                .font(.subheadline)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("No model loaded")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("Status")
                }

                Section {
                    ForEach(ModelConfig.availableModels) { model in
                        ModelRowView(
                            model: model,
                            downloadState: modelManager.downloadStates[model.id] ?? .notDownloaded,
                            onDownload: { downloadModel(model) },
                            onLoad: { loadModel(model) },
                            onDelete: {
                                modelToDelete = model
                                showingDeleteAlert = true
                            }
                        )
                    }
                } header: {
                    Text("Available Models")
                } footer: {
                    let totalSize = ModelManager.formatBytes(modelManager.getTotalModelSize())
                    Text("Total storage used: \(totalSize)")
                }
            }
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Model", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let model = modelToDelete {
                        deleteModel(model)
                    }
                }
            } message: {
                if let model = modelToDelete {
                    Text("Are you sure you want to delete \(model.displayName)? This will free up approximately \(model.fileSizeMB)MB.")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading model...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
            }
        }
        .onAppear {
            chatService.setModelContext(modelContext)
        }
    }

    private func downloadModel(_ model: ModelConfig) {
        Task {
            do {
                try await modelManager.downloadModel(model)
            } catch {
                errorMessage = "Failed to download model: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func loadModel(_ model: ModelConfig) {
        Task {
            isLoading = true
            do {
                try await chatService.initialize(with: model)
                selectedModel = model
                dismiss()
            } catch {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                showError = true
            }
            isLoading = false
        }
    }

    private func deleteModel(_ model: ModelConfig) {
        do {
            try modelManager.deleteModel(model)
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
            showError = true
        }
    }
}

/// Row view for a single model
struct ModelRowView: View {
    let model: ModelConfig
    let downloadState: ModelDownloadState
    let onDownload: () -> Void
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)

                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Action button
                Group {
                    switch downloadState {
                    case .notDownloaded:
                        Button {
                            onDownload()
                        } label: {
                            Label("Download", systemImage: "arrow.down.circle")
                                .font(.subheadline)
                        }

                    case .downloading(let progress):
                        VStack(spacing: 4) {
                            ProgressView(value: progress)
                                .frame(width: 60)
                            Text("\(Int(progress * 100))%")
                                .font(.caption2)
                        }

                    case .downloaded:
                        HStack(spacing: 8) {
                            Button {
                                onLoad()
                            } label: {
                                Text("Load")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }

                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline)
                            }
                        }

                    case .error(let message):
                        VStack(alignment: .trailing, spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Error")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            // Model metadata
            HStack(spacing: 12) {
                Label("\(model.fileSizeMB) MB", systemImage: "internaldrive")
                Label("\(model.contextLength) tokens", systemImage: "doc.text")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Recommended for tags
            if !model.recommendedFor.isEmpty {
                HStack(spacing: 6) {
                    ForEach(model.recommendedFor.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ModelSelectionView()
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}
