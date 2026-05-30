import SwiftUI
import DesignSystem
import Common

/// Shared OTP step layout for login, register, and similar flows.
public struct OtpVerificationView: View {
    @Binding private var otpCode: String
    private let title: String
    private let subtitle: String
    private let submitTitle: String
    private let otpError: String?
    private let otpInfoMessage: String?
    private let isLoading: Bool
    private let onResend: () -> Void
    private let onSubmit: () -> Void
    private let onBack: () -> Void

    public init(
        otpCode: Binding<String>,
        title: String,
        subtitle: String,
        submitTitle: String,
        otpError: String?,
        otpInfoMessage: String?,
        isLoading: Bool,
        onResend: @escaping () -> Void,
        onSubmit: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self._otpCode = otpCode
        self.title = title
        self.subtitle = subtitle
        self.submitTitle = submitTitle
        self.otpError = otpError
        self.otpInfoMessage = otpInfoMessage
        self.isLoading = isLoading
        self.onResend = onResend
        self.onSubmit = onSubmit
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            VStack(spacing: SplickTheme.Spacing.xs) {
                Text(title)
                    .font(SplickTheme.Typography.title)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let otpInfoMessage {
                Text(otpInfoMessage)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SplickOtpField(code: $otpCode, errorMessage: otpError)

            SplickButton(
                submitTitle,
                isLoading: isLoading,
                isDisabled: otpCode.count != SplickOtpField.defaultLength
            ) {
                hideKeyboard()
                onSubmit()
            }

            HStack(spacing: SplickTheme.Spacing.md) {
                Button("Back", action: onBack)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                Spacer()

                Button("Resend code", action: onResend)
                    .font(SplickTheme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .disabled(isLoading)
            }
        }
    }
}
