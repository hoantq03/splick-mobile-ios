import SwiftUI

public struct EmptyStateView: View {
    private let icon: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(SplickTheme.Colors.textTertiary)

            Text(title)
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            Text(message)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.xl)

            if let actionTitle, let action {
                SplickButton(actionTitle, style: .primary) {
                    action()
                }
                .padding(.horizontal, SplickTheme.Spacing.xxl)
                .padding(.top, SplickTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
