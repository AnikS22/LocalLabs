//
//  DeviceSyncView.swift
//  LocalLabs
//
//  UI for syncing conversations between devices
//

import SwiftUI
import SwiftData
import MultipeerConnectivity

/// View for device-to-device sync
struct DeviceSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var syncService = SyncService.shared
    @State private var selectedConversation: Conversation?
    @State private var showingConversationPicker = false
    @State private var syncMode: SyncMode = .send

    @Query private var conversations: [Conversation]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Sync Mode Picker
                Picker("Sync Mode", selection: $syncMode) {
                    Text("Send").tag(SyncMode.send)
                    Text("Receive").tag(SyncMode.receive)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Status
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)

                        Text(syncService.connectionState.description)
                            .font(.headline)
                    }

                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                if syncMode == .send {
                    // Send Mode
                    sendModeView
                } else {
                    // Receive Mode
                    receiveModeView
                }

                Spacer()
            }
            .navigationTitle("Device Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        syncService.stopAll()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingConversationPicker) {
                conversationPickerView
            }
            .onDisappear {
                syncService.stopAll()
            }
        }
    }

    // MARK: - Send Mode View

    private var sendModeView: some View {
        VStack(spacing: 16) {
            // Selected conversation
            if let conversation = selectedConversation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Conversation")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        VStack(alignment: .leading) {
                            Text(conversation.title)
                                .font(.headline)
                            Text("\(conversation.messages.count) messages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Change") {
                            showingConversationPicker = true
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            } else {
                Button {
                    showingConversationPicker = true
                } label: {
                    Label("Select Conversation", systemImage: "bubble.left.and.bubble.right")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            // Start browsing button
            if syncService.connectionState == .idle {
                Button {
                    syncService.startBrowsing()
                } label: {
                    Label("Find Devices", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(selectedConversation == nil)
            }

            // Nearby devices
            if syncService.connectionState == .browsing || syncService.connectionState == .connecting {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nearby Devices")
                        .font(.headline)

                    if syncService.nearbyPeers.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Searching...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(syncService.nearbyPeers, id: \.displayName) { peer in
                            Button {
                                syncService.invitePeer(peer)
                            } label: {
                                HStack {
                                    Image(systemName: "iphone")
                                    Text(peer.displayName)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Connected - Send button
            if syncService.connectionState == .connected,
               let peer = syncService.connectedPeers.first,
               let conversation = selectedConversation {
                Button {
                    sendConversation(conversation, to: peer)
                } label: {
                    Label("Send Conversation", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Receive Mode View

    private var receiveModeView: some View {
        VStack(spacing: 16) {
            // Start advertising button
            if syncService.connectionState == .idle {
                Button {
                    syncService.startAdvertising()
                } label: {
                    Label("Make Discoverable", systemImage: "wave.3.right")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            // Waiting for connection
            if syncService.connectionState == .advertising || syncService.connectionState == .connecting {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Waiting for sender...")
                        .font(.headline)

                    Text("Other device should see '\(UIDevice.current.name)' in their device list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            // Connected - waiting for data
            if syncService.connectionState == .connected {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Connected!")
                        .font(.headline)

                    Text("Waiting to receive conversation...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Received conversation
            if let received = syncService.receivedConversation {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Received!")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(received.title)
                            .font(.headline)
                        Text("\(received.messages.count) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    Button {
                        saveReceivedConversation(received)
                    } label: {
                        Label("Save Conversation", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Conversation Picker

    private var conversationPickerView: some View {
        NavigationStack {
            List(conversations) { conversation in
                Button {
                    selectedConversation = conversation
                    showingConversationPicker = false
                } label: {
                    VStack(alignment: .leading) {
                        Text(conversation.title)
                            .font(.headline)
                        Text("\(conversation.messages.count) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Select Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingConversationPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch syncService.connectionState {
        case .idle: return .gray
        case .advertising, .browsing, .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    private var statusMessage: String {
        switch syncService.connectionState {
        case .idle:
            return syncMode == .send ? "Select a conversation to send" : "Tap 'Make Discoverable' to receive"
        case .advertising:
            return "Other devices can now see you"
        case .browsing:
            return "Searching for nearby devices..."
        case .connecting:
            return "Establishing secure connection..."
        case .connected:
            return "Securely connected"
        case .error(let msg):
            return msg
        }
    }

    private func sendConversation(_ conversation: Conversation, to peer: MultipeerConnectivity.MCPeerID) {
        do {
            let transferable = TransferableConversation(from: conversation)
            try syncService.sendConversation(transferable, to: peer)
        } catch {
            print("❌ Failed to send: \(error)")
        }
    }

    private func saveReceivedConversation(_ transferable: TransferableConversation) {
        // Create new conversation from transferred data
        let conversation = Conversation(
            title: transferable.title + " (synced)",
            modelName: transferable.modelName,
            createdAt: transferable.createdAt
        )

        modelContext.insert(conversation)

        // Add messages
        for transferableMsg in transferable.messages {
            let message = Message(
                content: transferableMsg.content,
                role: MessageRole(rawValue: transferableMsg.role) ?? .user,
                timestamp: transferableMsg.timestamp
            )
            message.conversation = conversation
            conversation.messages.append(message)
            modelContext.insert(message)
        }

        try? modelContext.save()

        // Clean up
        syncService.stopAll()
        dismiss()
    }
}

// MARK: - Supporting Types

enum SyncMode {
    case send
    case receive
}

#Preview {
    DeviceSyncView()
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}
