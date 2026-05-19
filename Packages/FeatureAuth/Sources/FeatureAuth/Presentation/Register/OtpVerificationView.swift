import SwiftUI
import DesignSystem
import Common

struct OtpVerificationView: View {
    @Binding var otpCode: String
    let title: String
    let subtitle: String
    let submitTitle: String
    let otpError: String?
    let otpInfoMessage: String?
    let isLoading: Bool
    let onResend: () -> Void
    let onSubmit: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            VStack(spacing: SplickTheme.Spacing.xs) {
                Text(title)
                    .font(SplickTheme.Typography.title)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)

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

            SplickTextField(
                "Verification code",
                text: $otpCode,
                errorMessage: otpError,
                icon: "number"
            )
            .textContentType(.oneTimeCode)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: otpCode) { newValue in
                let digits = newValue.filter(\.isNumber)
                if digits.count > 6 {
                    otpCode = String(digits.prefix(6))
                } else if digits != newValue {
                    otpCode = digits
                }
            }

            SplickButton(submitTitle, isLoading: isLoading, isDisabled: otpCode.count != 6) {
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
