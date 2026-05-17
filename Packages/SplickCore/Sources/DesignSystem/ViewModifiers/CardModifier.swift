import SwiftUI

public struct CardModifier: ViewModifier {
    private let padding: CGFloat

    public init(padding: CGFloat = SplickTheme.Spacing.md) {
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(SplickTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
            .shadow(
                color: SplickTheme.Shadow.small.color,
                radius: SplickTheme.Shadow.small.radius,
                y: SplickTheme.Shadow.small.y
            )
    }
}

extension View {
    public func splickCard(padding: CGFloat = SplickTheme.Spacing.md) -> some View {
        modifier(CardModifier(padding: padding))
    }
}
