//
//  MessageRow.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import SwiftUI

/// A view that displays a single message in the chat
struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message bubble
                Text(message.content)
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
                    .textSelection(.enabled)

                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return .blue
        case .assistant:
            return Color(.systemGray5)
        case .system:
            return .orange
        }
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Preview showing different message types
#Preview {
    VStack(spacing: 8) {
        MessageRow(message: Message(content: "Hello, how are you?", role: .user))
        MessageRow(message: Message(content: "I'm doing great! How can I help you today?", role: .assistant))
    }
    .padding()
}
