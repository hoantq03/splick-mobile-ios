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
                icon: "envelope"
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            SplickTextField(
                "Username",
                text: $viewModel.username,
                errorMessage: viewModel.usernameError,
                icon: "person"
            )
            .textContentType(.username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

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
                icon: "lock"
            )
            .textContentType(.newPassword)

            SplickTextField(
                "Confirm Password",
                text: $viewModel.confirmPassword,
                isSecure: true,
                errorMessage: viewModel.confirmPasswordError,
                icon: "lock.fill"
            )
            .textContentType(.newPassword)
        }
    }

    private var accountDetailsActions: some View {
        SplickButton(
            "Continue",
            isLoading: viewModel.state.isLoading,
            isDisabled: !AppConstants.Dev.useMockData
                && (viewModel.email.isEmpty || viewModel.username.isEmpty
                    || viewModel.password.isEmpty || viewModel.confirmPassword.isEmpty)
        ) {
            Task { await viewModel.requestOtpAndContinue() }
        }
    }
}
