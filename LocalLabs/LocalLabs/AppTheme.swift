//
//  AppTheme.swift
//  LocalLabs
//
//  Centralized design system for consistent styling
//

import SwiftUI

/// Centralized theme configuration for the app
struct AppTheme {

    // MARK: - Colors

    /// Color palette for the app
    struct Colors {
        /// Primary accent color - neon green
        static let accent = Color(red: 0.0, green: 1.0, blue: 0.498) // #00FF7F

        /// Background colors
        static let background = Color.black
        static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
        static let cardBackgroundSecondary = Color(red: 0.17, green: 0.17, blue: 0.18) // #2C2C2E

        /// Text colors
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93
        static let textTertiary = Color(red: 0.42, green: 0.42, blue: 0.43) // #6B6B6D

        /// Message bubble colors
        static let userMessageBackground = accent
        static let assistantMessageBackground = cardBackground
        static let userMessageText = Color.black
        static let assistantMessageText = textPrimary

        /// Action card colors
        static let actionCardPrimary = accent
        static let actionCardSecondary = cardBackgroundSecondary
    }

    // MARK: - Typography

    /// Typography system
    struct Typography {
        /// Large title for greetings
        static func largeTitle() -> Font {
            .system(size: 20, weight: .semibold)
        }

        /// Title for section headers
        static func title() -> Font {
            .system(size: 24, weight: .bold)
        }

        /// Subtitle for secondary headings
        static func subtitle() -> Font {
            .system(size: 17, weight: .regular)
        }

        /// Headline for card titles
        static func headline() -> Font {
            .system(size: 15, weight: .semibold)
        }

        /// Body text
        static func body() -> Font {
            .system(size: 15, weight: .regular)
        }

        /// Subheadline for secondary text
        static func subheadline() -> Font {
            .system(size: 13, weight: .regular)
        }

        /// Caption for timestamps
        static func caption() -> Font {
            .system(size: 11, weight: .regular)
        }
    }

    // MARK: - Spacing

    /// Spacing constants
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    /// Corner radius values
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
    }

    // MARK: - Shadows & Effects

    /// Shadow and glow effects
    struct Effects {
        /// Green glow effect for accent elements
        static func accentGlow() -> some View {
            EmptyView()
                .shadow(color: Colors.accent.opacity(0.3), radius: 8, x: 0, y: 0)
        }

        /// Subtle shadow for cards
        static func cardShadow() -> some View {
            EmptyView()
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        }

        /// Strong shadow for elevated elements
        static func elevatedShadow() -> some View {
            EmptyView()
                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
        }
    }

    // MARK: - Animations

    /// Standard animation configurations
    struct Animations {
        static let springResponse: Double = 0.3
        static let springDamping: Double = 0.7

        /// Spring animation for interactions
        static var spring: Animation {
            .spring(response: springResponse, dampingFraction: springDamping)
        }

        /// Smooth ease animation
        static var smooth: Animation {
            .easeInOut(duration: 0.2)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card styling
    func cardStyle(backgroundColor: Color = AppTheme.Colors.cardBackground) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(AppTheme.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    /// Apply action card styling with optional accent glow
    func actionCardStyle(isAccent: Bool = false) -> some View {
        self
            .background(isAccent ? AppTheme.Colors.actionCardPrimary : AppTheme.Colors.actionCardSecondary)
            .cornerRadius(AppTheme.CornerRadius.large)
            .shadow(
                color: isAccent ? AppTheme.Colors.accent.opacity(0.3) : Color.black.opacity(0.2),
                radius: isAccent ? 8 : 4,
                x: 0,
                y: isAccent ? 0 : 2
            )
    }
}
