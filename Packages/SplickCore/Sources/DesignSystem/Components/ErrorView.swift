import SwiftUI

public struct ErrorView: View {
    private let message: String
    private let retryAction: (() -> Void)?

    public init(message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(SplickTheme.Colors.warning)

            Text(message)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.xl)

            if let retryAction {
                SplickButton("Try Again", style: .secondary) {
                    retryAction()
                }
                .padding(.horizontal, SplickTheme.Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
