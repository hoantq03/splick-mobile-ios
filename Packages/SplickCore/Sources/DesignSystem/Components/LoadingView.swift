import SwiftUI

public struct LoadingView: View {
    private let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            ProgressView()
                .controlSize(.regular)
                .tint(SplickTheme.Colors.primaryGradientStart)

            if let message {
                Text(message)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
