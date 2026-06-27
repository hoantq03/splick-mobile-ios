import SwiftUI

public struct CardModifier: ViewModifier {
    private let padding: CGFloat
    private let cornerRadius: CGFloat

    public init(
        padding: CGFloat = SplickTheme.Spacing.md,
        cornerRadius: CGFloat = SplickTheme.CornerRadius.card
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(SplickTheme.Colors.cardBackground)
                    .shadow(
                        color: SplickTheme.Shadow.card.color,
                        radius: SplickTheme.Shadow.card.radius,
                        x: SplickTheme.Shadow.card.x,
                        y: SplickTheme.Shadow.card.y
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    public func splickCard(
        padding: CGFloat = SplickTheme.Spacing.md,
        cornerRadius: CGFloat = SplickTheme.CornerRadius.card
    ) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}
