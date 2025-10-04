//
//  ActionCard.swift
//  LocalLabs
//
//  Reusable action card component for home screen
//

import SwiftUI

/// A card button for primary actions on the home screen
struct ActionCard: View {
    let title: String
    let subtitle: String?
    let isAccent: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(
        title: String,
        subtitle: String? = nil,
        isAccent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isAccent = isAccent
        self.action = action
    }

    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.body())
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTheme.Typography.caption())
                            .foregroundColor(textColor.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                HStack {
                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .actionCardStyle(isAccent: isAccent)
            .scaleEffect(isPressed ? 0.96 : 1.0)
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
    }

    private var textColor: Color {
        isAccent ? AppTheme.Colors.userMessageText : AppTheme.Colors.textPrimary
    }
}

#Preview {
    ZStack {
        AppTheme.Colors.background
            .ignoresSafeArea()

        HStack(spacing: AppTheme.Spacing.lg) {
            ActionCard(
                title: "Engage in conversation with AI.",
                isAccent: true
            ) {
                print("Accent card tapped")
            }

            ActionCard(
                title: "Converse with Artificial Intelligence.",
                subtitle: "Powered by local models",
                isAccent: false
            ) {
                print("Secondary card tapped")
            }
        }
        .padding()
    }
}
