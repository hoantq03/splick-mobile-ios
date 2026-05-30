import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct ForgotPasswordView: View {
    @StateObject private var viewModel: ForgotPasswordViewModel
    @Environment(\.dismiss) private var dismiss
    private let onAuthenticated: ((User) -> Void)?

    public init(
        viewModel: @autoclosure @escaping () -> ForgotPasswordViewModel,
        onAuthenticated: ((User) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    switch viewModel.step {
                    case .email:
                        emailStep
                    case .reset:
                        resetStep
                    }

                    if let error = viewModel.state.error {
                        Text(error)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.lg)
                .padding(.top, SplickTheme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: viewModel.state) { state in
                if case .loaded(let session) = state {
                    onAuthenticated?(session.user)
                    dismiss()
                }
            }
        }
    }

    private var emailStep: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Text("Enter the email for your account. We will send a verification code.")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            SplickTextField(
                "Email",
                text: $viewModel.email,
                errorMessage: viewModel.emailError,
                icon: "envelope"
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: viewModel.email) { _ in viewModel.validateEmailField() }

            SplickButton(
                "Send code",
                isLoading: viewModel.state.isLoading,
                isDisabled: viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await viewModel.requestResetCode() }
            }
        }
    }

    private var resetStep: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            VStack(spacing: SplickTheme.Spacing.xs) {
                Text("Enter verification code")
                    .font(SplickTheme.Typography.title)
                Text("Sent to \(viewModel.email)")
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            if let otpInfoMessage = viewModel.otpInfoMessage {
                Text(otpInfoMessage)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SplickOtpField(code: $viewModel.otpCode, errorMessage: viewModel.otpError)

            Button("Resend code") {
                Task { await viewModel.resendCode() }
            }
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)

            Button("Use a different email") {
                viewModel.goBackToEmail()
            }
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)

            SplickTextField(
                "New password",
                text: $viewModel.password,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock"
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.password) { _ in viewModel.validatePasswordField() }

            SplickTextField(
                "Confirm password",
                text: $viewModel.confirmPassword,
                isSecure: true,
                errorMessage: viewModel.confirmPasswordError,
                icon: "lock.fill"
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }

            SplickButton(
                "Reset password",
                isLoading: viewModel.state.isLoading,
                isDisabled: resetSubmitDisabled
            ) {
                Task { await viewModel.resetPassword() }
            }
        }
    }

    private var resetSubmitDisabled: Bool {
        viewModel.otpCode.count != 6
            || !viewModel.passwordStrength.isStrong
            || viewModel.password != viewModel.confirmPassword
    }
}
