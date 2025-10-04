//
//  ConversationHistoryRow.swift
//  LocalLabs
//
//  Conversation list row component for home screen
//

import SwiftUI

/// A row displaying a conversation in the history list
struct ConversationHistoryRow: View {
    let conversation: Conversation
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon circle
                Circle()
                    .fill(iconColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(iconText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.userMessageText)
                    )

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title)
                        .font(AppTheme.Typography.body())
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage.content)
                            .font(AppTheme.Typography.caption())
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(AppTheme.Typography.caption())
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .italic()
                    }
                }

                Spacer()

                // Timestamp and chevron
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatTime(conversation.updatedAt))
                        .font(AppTheme.Typography.caption())
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .cardStyle(backgroundColor: cardBackgroundColor)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(AppTheme.Animations.spring, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Conversation", systemImage: "trash")
            }
        }
    }

    // Generate a color based on conversation title
    private var iconColor: Color {
        let colors: [Color] = [
            AppTheme.Colors.accent,
            Color(red: 1.0, green: 0.584, blue: 0.0), // Orange
            Color(red: 0.561, green: 0.353, blue: 0.969), // Purple
            Color(red: 1.0, green: 0.271, blue: 0.227), // Red
            Color(red: 0.204, green: 0.780, blue: 0.349), // Green
            Color(red: 0.0, green: 0.478, blue: 1.0) // Blue
        ]

        // Use conversation ID to deterministically pick a color
        let hash = abs(conversation.id.hashValue)
        return colors[hash % colors.count]
    }

    // Generate icon text from conversation title
    private var iconText: String {
        let title = conversation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return "💬"
        }

        // Try to get first letter of first word
        if let firstChar = title.first {
            return String(firstChar).uppercased()
        }

        return "💬"
    }

    // Alternate card background based on position (for visual variety)
    private var cardBackgroundColor: Color {
        // Use conversation ID to alternate backgrounds
        let hash = abs(conversation.id.hashValue)
        return hash % 2 == 0 ? AppTheme.Colors.cardBackground : AppTheme.Colors.cardBackgroundSecondary
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ZStack {
        AppTheme.Colors.background
            .ignoresSafeArea()

        VStack(spacing: AppTheme.Spacing.md) {
            ConversationHistoryRow(
                conversation: Conversation(
                    title: "My GPT",
                    modelName: "llama-3.2-1b-instruct"
                ),
                onTap: { print("Tapped") },
                onDelete: { print("Delete") }
            )

            ConversationHistoryRow(
                conversation: Conversation(
                    title: "Thisjourney",
                    modelName: "llama-3.2-1b-instruct"
                ),
                onTap: { print("Tapped") },
                onDelete: { print("Delete") }
            )
        }
        .padding()
    }
}
