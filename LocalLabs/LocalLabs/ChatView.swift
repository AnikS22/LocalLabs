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
    @State private var viewModel = ChatViewModel()
    @State private var voiceViewModel = VoiceViewModel()
    @State private var showingModelSelection = false
    @State private var showingDeviceSync = false

    var body: some View {
        NavigationStack {
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
                                VStack(spacing: 16) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 60))
                                        .foregroundColor(.secondary)
                                    Text("No conversation yet")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                    Text("Start chatting with your local AI")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 100)
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
                VStack(spacing: 4) {
                    // Recording indicator
                    if voiceViewModel.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(0.8)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: voiceViewModel.isRecording)

                            Text(voiceViewModel.transcribedText.isEmpty ? "Listening..." : voiceViewModel.transcribedText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Button("Cancel") {
                                voiceViewModel.cancelRecording()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                    }

                    HStack(spacing: 12) {
                        // Microphone button
                        Button(action: {
                            Task {
                                if voiceViewModel.isRecording {
                                    let transcription = voiceViewModel.stopRecording()
                                    if !transcription.isEmpty {
                                        viewModel.userInput = transcription
                                        viewModel.sendMessage()
                                    }
                                } else {
                                    await voiceViewModel.startRecording()
                                }
                            }
                        }) {
                            Image(systemName: voiceViewModel.isRecording ? "mic.fill" : "mic")
                                .font(.title2)
                                .foregroundColor(voiceViewModel.isRecording ? .red : .blue)
                        }
                        .disabled(viewModel.isSending)

                        TextField("Message", text: $viewModel.userInput, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...5)
                            .disabled(viewModel.isSending || !viewModel.isReady || voiceViewModel.isRecording)
                            .onSubmit {
                                viewModel.sendMessage()
                            }

                        Button(action: {
                            viewModel.sendMessage()
                        }) {
                            Image(systemName: viewModel.isSending ? "stop.circle.fill" : "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(canSend ? .blue : .gray)
                        }
                        .disabled(!canSend && !viewModel.isSending)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle(viewModel.conversation?.title ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingModelSelection = true
                    } label: {
                        Label("Models", systemImage: "cube.box")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingDeviceSync = true
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // TTS Toggle
                        Toggle(isOn: $voiceViewModel.isTTSEnabled) {
                            Label("Voice Responses", systemImage: voiceViewModel.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                        }

                        Divider()

                        Button {
                            viewModel.startNewConversation()
                        } label: {
                            Label("New Chat", systemImage: "square.and.pencil")
                        }

                        if viewModel.conversation != nil {
                            Divider()

                            Button(role: .destructive) {
                                viewModel.deleteCurrentConversation()
                            } label: {
                                Label("Delete Chat", systemImage: "trash")
                            }
                        }

                        if let stats = viewModel.lastStats {
                            Divider()

                            Text("Last generation: \(String(format: "%.1f", stats.tokensPerSecond)) tok/s")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingModelSelection) {
                ModelSelectionView()
            }
            .sheet(isPresented: $showingDeviceSync) {
                DeviceSyncView()
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
            .alert("Microphone Permission Required", isPresented: $voiceViewModel.showPermissionAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("LocalLabs needs microphone and speech recognition permissions for voice input. Please enable them in Settings.")
            }
            .alert("Voice Error", isPresented: $voiceViewModel.showError) {
                Button("OK") {
                    voiceViewModel.showError = false
                }
            } message: {
                if let errorMessage = voiceViewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .onAppear {
                // Start a new conversation if none exists
                if viewModel.conversation == nil && viewModel.isReady {
                    viewModel.startNewConversation()
                }
            }
            .onChange(of: viewModel.streamingResponse) { oldValue, newValue in
                // Speak AI responses if TTS enabled
                if voiceViewModel.isTTSEnabled && !newValue.isEmpty && oldValue != newValue {
                    // Only speak when response is complete (not streaming individual tokens)
                    if !viewModel.isStreaming && !newValue.isEmpty {
                        voiceViewModel.speak(newValue)
                    }
                }
            }
            .onChange(of: viewModel.conversation?.messages.last) { _, newMessage in
                // Speak assistant messages when they're added
                if let message = newMessage,
                   message.role == .assistant,
                   voiceViewModel.isTTSEnabled,
                   !message.content.isEmpty {
                    voiceViewModel.speak(message.content)
                }
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
