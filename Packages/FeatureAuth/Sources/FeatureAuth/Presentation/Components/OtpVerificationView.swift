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
    private let cornerRadius: CGFloat
    private let showsBackButton: Bool
    private let backTitle: String
    private let resendTitle: String
    private let isResendDisabled: Bool
    private let secondaryActionTitle: String?
    private let onResend: () -> Void
    private let onSubmit: () -> Void
    private let onBack: () -> Void
    private let onSecondaryAction: (() -> Void)?
    private let autoFocus: Bool

    public init(
        otpCode: Binding<String>,
        title: String,
        subtitle: String,
        submitTitle: String,
        otpError: String?,
        otpInfoMessage: String?,
        isLoading: Bool,
        cornerRadius: CGFloat = SplickTheme.CornerRadius.medium,
        showsBackButton: Bool = true,
        backTitle: String = "Back",
        resendTitle: String = "Resend code",
        isResendDisabled: Bool = false,
        autoFocus: Bool = true,
        onResend: @escaping () -> Void,
        onSubmit: @escaping () -> Void,
        onBack: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self._otpCode = otpCode
        self.title = title
        self.subtitle = subtitle
        self.submitTitle = submitTitle
        self.otpError = otpError
        self.otpInfoMessage = otpInfoMessage
        self.isLoading = isLoading
        self.cornerRadius = cornerRadius
        self.showsBackButton = showsBackButton
        self.backTitle = backTitle
        self.resendTitle = resendTitle
        self.isResendDisabled = isResendDisabled
        self.onResend = onResend
        self.onSubmit = onSubmit
        self.onBack = onBack
        self.secondaryActionTitle = secondaryActionTitle
        self.onSecondaryAction = onSecondaryAction
        self.autoFocus = autoFocus
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

            SplickOtpField(
                code: $otpCode,
                errorMessage: otpError,
                autoFocus: autoFocus,
                cornerRadius: cornerRadius
            )

            SplickButton(
                submitTitle,
                isLoading: isLoading,
                isDisabled: otpCode.count != SplickOtpField.defaultLength,
                cornerRadius: cornerRadius
            ) {
                hideKeyboard()
                onSubmit()
            }

            if let secondaryActionTitle, let onSecondaryAction {
                Button(secondaryActionTitle, action: onSecondaryAction)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            HStack(spacing: SplickTheme.Spacing.md) {
                if showsBackButton {
                    Button(backTitle, action: onBack)
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                Spacer()

                Button(resendTitle, action: onResend)
                    .font(SplickTheme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        isResendDisabled
                            ? SplickTheme.Colors.textSecondary.opacity(0.55)
                            : SplickTheme.Colors.primaryGradientStart
                    )
                    .disabled(isResendDisabled || isLoading)
            }
        }
    }
}
