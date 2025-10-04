//
//  ChatView.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import SwiftUI
import SwiftData

/// Main chat interface view
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()
    @State private var showingModelSelection = false
    @State private var showingDeviceSync = false
    @State private var showingMenu = false

    let initialConversation: Conversation?

    init(conversation: Conversation? = nil) {
        self.initialConversation = conversation
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                CustomNavigationBar(
                title: viewModel.conversation?.title ?? "Chat",
                onBack: {
                    dismiss()
                },
                onModelSelect: {
                    showingModelSelection = true
                },
                onSync: {
                    showingDeviceSync = true
                },
                onMenu: {
                    showingMenu = true
                }
            )

            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if let conversation = viewModel.conversation {
                                ForEach(conversation.messages.sorted(by: { $0.timestamp < $1.timestamp })) { message in
                                    MessageRow(message: message)
                                        .id(message.id)
                                }
                            } else {
                                // Empty state
                                VStack(spacing: AppTheme.Spacing.md) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                    Text("No conversation yet")
                                        .font(AppTheme.Typography.body())
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    Text("Start chatting with your local AI")
                                        .font(AppTheme.Typography.caption())
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                }
                                .padding(.top, 80)
                            }

                            // Streaming response indicator
                            if viewModel.isStreaming && !viewModel.streamingResponse.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(viewModel.streamingResponse)
                                            .padding(12)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(16)
                                            .textSelection(.enabled)

                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                            Text("Generating...")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                    .frame(maxWidth: 280, alignment: .leading)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .id("streaming")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.conversation?.messages.count) { _, _ in
                        // Scroll to bottom when new messages arrive
                        if let lastMessage = viewModel.conversation?.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.streamingResponse) { _, _ in
                        // Scroll during streaming
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input area
                HStack(spacing: 12) {
                    TextField("Message", text: $viewModel.userInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .disabled(viewModel.isSending || !viewModel.isReady)
                        .tint(AppTheme.Colors.accent)
                        .onSubmit {
                            viewModel.sendMessage()
                        }

                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: viewModel.isSending ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(canSend ? AppTheme.Colors.accent : AppTheme.Colors.textTertiary)
                    }
                    .disabled(!canSend && !viewModel.isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.background)
            }
        }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingModelSelection) {
            ModelSelectionView()
        }
        .sheet(isPresented: $showingDeviceSync) {
            DeviceSyncView()
        }
        .sheet(isPresented: $showingMenu) {
            MenuSheet(
                hasConversation: viewModel.conversation != nil,
                stats: viewModel.lastStats,
                onNewChat: {
                    showingMenu = false
                    viewModel.startNewConversation()
                },
                onDeleteChat: {
                    showingMenu = false
                    viewModel.deleteCurrentConversation()
                }
            )
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            // Load initial conversation if provided, otherwise start new
            if let conversation = initialConversation {
                viewModel.loadConversation(conversation)
            } else if viewModel.conversation == nil && viewModel.isReady {
                viewModel.startNewConversation()
            }
        }
    }

    private var canSend: Bool {
        !viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        viewModel.isReady &&
        !viewModel.isSending
    }
}

#Preview {
    ChatView()
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}
