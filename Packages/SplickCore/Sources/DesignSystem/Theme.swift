import SwiftUI

public enum SplickTheme {

    // MARK: - Colors

    public enum Colors {
        public static let primary = Color("AccentColor", bundle: .module)
        public static let primaryGradientStart = Color(hex: 0x6C63FF)
        public static let primaryGradientEnd = Color(hex: 0x4ECDC4)

        public static let background = Color(.systemBackground)
        public static let secondaryBackground = Color(.secondarySystemBackground)
        public static let tertiaryBackground = Color(.tertiarySystemBackground)

        public static let textPrimary = Color(.label)
        public static let textSecondary = Color(.secondaryLabel)
        public static let textTertiary = Color(.tertiaryLabel)

        public static let success = Color(hex: 0x27AE60)
        public static let warning = Color(hex: 0xF2994A)
        public static let error = Color(hex: 0xEB5757)
        public static let info = Color(hex: 0x2F80ED)

        public static let cardBackground = Color(.secondarySystemBackground)
        public static let divider = Color(.separator)

        public static var primaryGradient: LinearGradient {
            LinearGradient(
                colors: [primaryGradientStart, primaryGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let extraLarge: CGFloat = 24
        public static let pill: CGFloat = 999
    }

    // MARK: - Shadows

    public enum Shadow {
        public static let small = ShadowStyle(color: .black.opacity(0.05), radius: 4, y: 2)
        public static let medium = ShadowStyle(color: .black.opacity(0.08), radius: 8, y: 4)
        public static let large = ShadowStyle(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

public struct ShadowStyle {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat
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
