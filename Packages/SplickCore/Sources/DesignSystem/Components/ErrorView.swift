import SwiftUI
import Common

public struct ErrorView: View {
    private let message: String
    private let supportReference: String?
    private let retryAction: (() -> Void)?

    public init(message: String, supportReference: String? = nil, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.supportReference = supportReference
        self.retryAction = retryAction
    }

    public init(error: Error, retryAction: (() -> Void)? = nil) {
        self.message = SplickErrorFormatting.userMessage(for: error)
        self.supportReference = SplickErrorFormatting.supportTraceId(for: error)
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

            if let supportReference, !supportReference.isEmpty {
                VStack(spacing: SplickTheme.Spacing.xs) {
                    Text("Reference ID")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                    Text(supportReference)
                        .font(SplickTheme.Typography.caption.monospaced())
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)
            }

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
