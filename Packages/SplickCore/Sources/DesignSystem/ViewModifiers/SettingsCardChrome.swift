import SwiftUI

/// Soft floating card chrome shared by profile settings groups, connected accounts,
/// and password/account security forms — matches Android `SplickSettingsGroup`.
public struct SettingsCardChromeModifier: ViewModifier {
    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = SplickTheme.CornerRadius.control) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(SplickTheme.Colors.cardBackground)
                    .shadow(
                        color: SplickTheme.Shadow.card.color,
                        radius: SplickTheme.Shadow.card.radius,
                        x: SplickTheme.Shadow.card.x,
                        y: SplickTheme.Shadow.card.y
                    )
                    .overlay {
                        shape.strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    /// Apply settings-group card chrome without adding content padding.
    public func splickSettingsCardChrome(
        cornerRadius: CGFloat = SplickTheme.CornerRadius.control
    ) -> some View {
        modifier(SettingsCardChromeModifier(cornerRadius: cornerRadius))
    }
}
