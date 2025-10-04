//
//  CustomNavigationBar.swift
//  LocalLabs
//
//  Custom navigation bar component matching app theme
//

import SwiftUI

/// Custom navigation bar for ChatView
struct CustomNavigationBar: View {
    let title: String
    let onBack: () -> Void
    let onModelSelect: () -> Void
    let onSync: () -> Void
    let onMenu: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)
            }

            // Model selection button
            Button(action: onModelSelect) {
                Image(systemName: "cube.box")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(AppTheme.Colors.accent)
            }

            // Sync button
            Button(action: onSync) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppTheme.Colors.accent)
            }

            // Title
            Text(title)
                .font(AppTheme.Typography.body())
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer()

            // Menu button
            Button(action: onMenu) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppTheme.Colors.accent)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
    }
}

#Preview {
    VStack {
        CustomNavigationBar(
            title: "Hi",
            onBack: { print("Back") },
            onModelSelect: { print("Models") },
            onSync: { print("Sync") },
            onMenu: { print("Menu") }
        )
        Spacer()
    }
    .background(AppTheme.Colors.background)
}
