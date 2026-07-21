import SwiftUI
import Common
import DesignSystem
import Localization

public struct ErrorView: View {
    @Environment(\.languageService) private var languageService

    private let error: Error?
    private let staticMessage: String?
    private let retryAction: (() -> Void)?

    public init(message: String, retryAction: (() -> Void)? = nil) {
        self.error = nil
        self.staticMessage = message
        self.retryAction = retryAction
    }

    public init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.staticMessage = nil
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.warning.opacity(0.08))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(SplickTheme.Colors.warning.opacity(0.14))
                    .frame(width: 96, height: 96)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.warning)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.bottom, SplickTheme.Spacing.xs)

            Text(titleLabel)
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(resolvedMessage)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, SplickTheme.Spacing.xl)

            if let retryAction {
                SplickButton(retryLabel, style: .primary) {
                    retryAction()
                }
                .padding(.horizontal, SplickTheme.Spacing.xxl)
                .padding(.top, SplickTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, SplickTheme.Spacing.md)
    }

    private var resolvedMessage: String {
        if let error {
            if let languageService {
                return languageService.localizedMessage(for: error)
            }
            return SplickErrorFormatting.userMessage(for: error)
        }
        return staticMessage ?? ""
    }

    private var titleLabel: String {
        languageService?.text(.commonErrorTitle) ?? L10n.string(.commonErrorTitle, locale: .default)
    }

    private var retryLabel: String {
        languageService?.text(.commonTryAgain) ?? L10n.string(.commonTryAgain, locale: .default)
    }
}
