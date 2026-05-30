import SwiftUI
import Common
import DesignSystem
import Localization

public struct ErrorView: View {
    @Environment(\.languageService) private var languageService

    private let error: Error?
    private let staticMessage: String?
    private let supportReference: String?
    private let retryAction: (() -> Void)?

    public init(message: String, supportReference: String? = nil, retryAction: (() -> Void)? = nil) {
        self.error = nil
        self.staticMessage = message
        self.supportReference = supportReference
        self.retryAction = retryAction
    }

    public init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.staticMessage = nil
        self.supportReference = SplickErrorFormatting.supportTraceId(for: error)
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(SplickTheme.Colors.warning)

            Text(resolvedMessage)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.xl)

            if let supportReference, !supportReference.isEmpty {
                VStack(spacing: SplickTheme.Spacing.xs) {
                    Text(referenceLabel)
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
                SplickButton(retryLabel, style: .secondary) {
                    retryAction()
                }
                .padding(.horizontal, SplickTheme.Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var referenceLabel: String {
        languageService?.text(.commonReferenceId) ?? L10n.string(.commonReferenceId, locale: .default)
    }

    private var retryLabel: String {
        languageService?.text(.commonTryAgain) ?? L10n.string(.commonTryAgain, locale: .default)
    }
}
