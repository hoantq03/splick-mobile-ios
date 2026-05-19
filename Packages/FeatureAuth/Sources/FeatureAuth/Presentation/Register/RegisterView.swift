import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct RegisterView: View {
    @StateObject private var viewModel: RegisterViewModel
    private let onAuthenticated: ((User) -> Void)?

    public init(
        viewModel: @autoclosure @escaping () -> RegisterViewModel,
        onAuthenticated: ((User) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                headerSection

                switch viewModel.step {
                case .accountDetails:
                    accountDetailsSection
                    accountDetailsActions
                case .emailOtp:
                    EmailOtpVerificationView(
                        otpCode: $viewModel.otpCode,
                        email: viewModel.email,
                        otpError: viewModel.otpError,
                        otpInfoMessage: viewModel.otpInfoMessage,
                        isLoading: viewModel.state.isLoading,
                        onResend: { Task { await viewModel.resendOtp() } },
                        onSubmit: { Task { await viewModel.register() } },
                        onBack: { viewModel.goBackToAccountDetails() }
                    )
                }

                if let error = viewModel.state.error {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .padding(.top, SplickTheme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SplickTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showPasswordRequirements) {
            PasswordRequirementsSheet(result: viewModel.passwordStrength)
        }
        .onChange(of: viewModel.state) { state in
            if case .loaded(let session) = state {
                onAuthenticated?(session.user)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            Text("Create Account")
                .font(SplickTheme.Typography.largeTitle)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            Text(viewModel.step == .accountDetails
                 ? "Join your friends on Splick"
                 : "Almost there — verify your email")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .padding(.bottom, SplickTheme.Spacing.md)
    }

    private var accountDetailsSection: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            SplickTextField(
                "Email",
                text: $viewModel.email,
                errorMessage: viewModel.emailError,
                icon: "envelope",
                validationStatus: viewModel.emailStatus
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: viewModel.email) { _ in viewModel.validateEmailField() }

            SplickTextField(
                "Username",
                text: $viewModel.username,
                errorMessage: viewModel.usernameError,
                icon: "person",
                validationStatus: viewModel.usernameStatus
            )
            .textContentType(.username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: viewModel.username) { _ in viewModel.validateUsernameField() }

            SplickTextField(
                "Display name (optional)",
                text: $viewModel.displayName,
                icon: "textformat"
            )
            .textContentType(.name)

            SplickTextField(
                "Password",
                text: $viewModel.password,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock",
                validationStatus: viewModel.passwordStatus,
                onValidationAccessoryTap: { viewModel.showPasswordRequirements = true }
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.password) { _ in viewModel.validatePasswordField() }

            SplickTextField(
                "Confirm Password",
                text: $viewModel.confirmPassword,
                isSecure: true,
                errorMessage: viewModel.confirmPasswordError,
                icon: "lock.fill",
                validationStatus: viewModel.confirmPasswordStatus
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }
        }
    }

    private var accountDetailsActions: some View {
        SplickButton(
            "Continue",
            isLoading: viewModel.state.isLoading,
            isDisabled: !viewModel.canContinueAccountDetails
        ) {
            Task { await viewModel.requestOtpAndContinue() }
        }
    }
}
