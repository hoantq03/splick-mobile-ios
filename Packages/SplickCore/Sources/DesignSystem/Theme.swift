import SwiftUI

public enum SplickTheme {

    // MARK: - Colors

    public enum Colors {
        public static let primary = Color("AccentColor", bundle: .module)
        /// Camera mark left stop (Gicnova-aligned).
        public static let brandOrange = Color(hex: 0xFF872B)
        public static let brandPink = Color(hex: 0xFF517C)
        public static let brandBlue = Color(hex: 0x0095FF)
        public static let brandCanvas = Color(hex: 0xFFFEFD)
        public static let brandCanvasDark = Color(hex: 0x00020C)

        /// In-app accent matches the blue on the left of the logo.
        public static let primaryGradientStart = brandBlue
        public static let primaryGradientMid = Color(hex: 0x4ECDC4)
        public static let primaryGradientEnd = Color(hex: 0x2A9D8F)

        public static let background = Color(.systemBackground)
        public static let secondaryBackground = Color(.secondarySystemBackground)
        public static let tertiaryBackground = Color(.tertiarySystemBackground)

        public static let textPrimary = Color(.label)
        public static let textSecondary = Color(.secondaryLabel)
        public static let textTertiary = Color(.tertiaryLabel)

        public static let tabCameraRing = brandBlue
        public static let success = Color(hex: 0x27AE60)
        public static let warning = Color(hex: 0xF2994A)
        public static let error = Color(hex: 0xEB5757)
        public static let info = brandBlue

        public static let cardBackground = Color(.secondarySystemBackground)
        public static let divider = Color(.separator)

        public static var primaryGradient: LinearGradient {
            LinearGradient(
                colors: [primaryGradientStart, primaryGradientMid, primaryGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        public static var brandWordmarkGradient: LinearGradient {
            LinearGradient(
                colors: [brandBlue, brandPink, brandOrange],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        public static let authFieldFill = Color.white.opacity(0.88)
        public static let authFieldStroke = brandBlue.opacity(0.28)
        public static let authFieldStrokeFocused = brandPink.opacity(0.72)

        public static func resolvedBrandCanvas(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? brandCanvasDark : brandCanvas
        }

        public static func resolvedAuthFieldFill(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.white.opacity(0.12) : authFieldFill
        }
    }

    // MARK: - Typography

    public enum Typography {
        public static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        public static let title = Font.system(.title2, design: .rounded, weight: .semibold)
        public static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
        public static let body = Font.system(.body, design: .default)
        public static let callout = Font.system(.callout, design: .default)
        public static let caption = Font.system(.caption, design: .default)
        public static let captionBold = Font.system(.caption, design: .default, weight: .semibold)
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let xxxs: CGFloat = 2
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    public enum CornerRadius {
        public static let small: CGFloat = 10
        public static let medium: CGFloat = 14
        public static let large: CGFloat = 18
        public static let extraLarge: CGFloat = 28
        /// Grouped section cards — iOS 26-style continuous containers.
        public static let card: CGFloat = 22
        /// Fields and rows nested inside cards.
        public static let inset: CGFloat = 16
        /// Icon tiles and compact chips.
        public static let tile: CGFloat = 14
        public static let pill: CGFloat = 999
        /// Text fields, buttons, and OTP boxes in profile/settings flows.
        public static let control: CGFloat = extraLarge
    }

    // MARK: - Shadows

    public enum Shadow {
        public static let small = ShadowStyle(color: .black.opacity(0.04), radius: 8, y: 3)
        public static let medium = ShadowStyle(color: .black.opacity(0.06), radius: 14, y: 6)
        public static let large = ShadowStyle(color: .black.opacity(0.08), radius: 22, y: 10)
        /// Soft floating card (expense / feed grouped lists).
        public static let card = ShadowStyle(color: .black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}

public struct ShadowStyle {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

extension Color {
    public init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
