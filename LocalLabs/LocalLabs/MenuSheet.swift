//
//  MenuSheet.swift
//  LocalLabs
//
//  Menu sheet for ChatView options
//

import SwiftUI

/// Menu sheet displayed from ChatView
struct MenuSheet: View {
    let hasConversation: Bool
    let stats: GenerationStats?
    let onNewChat: () -> Void
    let onDeleteChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Options")
                    .font(AppTheme.Typography.headline())
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()
            }
            .padding(AppTheme.Spacing.lg)

            Divider()
                .background(AppTheme.Colors.textTertiary.opacity(0.3))

            // Menu Items
            VStack(spacing: 0) {
                // New Chat
                Button(action: onNewChat) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.accent)
                            .frame(width: 28)

                        Text("New Chat")
                            .font(AppTheme.Typography.body())
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Spacer()
                    }
                    .padding(AppTheme.Spacing.lg)
                }

                if hasConversation {
                    Divider()
                        .background(AppTheme.Colors.textTertiary.opacity(0.3))
                        .padding(.leading, 60)

                    // Delete Chat
                    Button(action: onDeleteChat) {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "trash")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                                .frame(width: 28)

                            Text("Delete Chat")
                                .font(AppTheme.Typography.body())
                                .foregroundColor(.red)

                            Spacer()
                        }
                        .padding(AppTheme.Spacing.lg)
                    }
                }

                if let stats = stats {
                    Divider()
                        .background(AppTheme.Colors.textTertiary.opacity(0.3))
                        .padding(.leading, 60)

                    // Stats
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .frame(width: 28)

                        Text("Last generation: \(String(format: "%.1f", stats.tokensPerSecond)) tok/s")
                            .font(AppTheme.Typography.subheadline())
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        Spacer()
                    }
                    .padding(AppTheme.Spacing.lg)
                }
            }

            Spacer()
        }
        .background(AppTheme.Colors.cardBackground)
    }
}

#Preview {
    MenuSheet(
        hasConversation: true,
        stats: GenerationStats(tokensGenerated: 100, timeElapsed: 5.0, tokensPerSecond: 20.0),
        onNewChat: { print("New Chat") },
        onDeleteChat: { print("Delete") }
    )
}
