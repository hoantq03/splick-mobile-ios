import SwiftUI
import DesignSystem
import Common

public struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    public init(viewModel: @autoclosure @escaping () -> LoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                headerSection
                formSection
                actionSection
                footerSection
            }
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .padding(.top, SplickTheme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SplickTheme.Colors.background)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            Text("Splick")
                .font(SplickTheme.Typography.largeTitle)
                .foregroundStyle(SplickTheme.Colors.primaryGradient)

            Text("Share moments. Split bills.")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .padding(.bottom, SplickTheme.Spacing.xl)
    }

    private var formSection: some View {
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
                "Password",
                text: $viewModel.password,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock"
            )
            .textContentType(.password)
        }
    }

    private var actionSection: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            if let error = viewModel.state.error {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
                    .multilineTextAlignment(.center)
            }

            SplickButton(
                "Sign In",
                isLoading: viewModel.state.isLoading,
                isDisabled: viewModel.email.isEmpty || viewModel.password.isEmpty
            ) {
                Task { await viewModel.login() }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Text("Don't have an account?")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            Button("Sign Up") {
                viewModel.showRegistration = true
            }
            .font(SplickTheme.Typography.callout)
            .fontWeight(.semibold)
            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .padding(.top, SplickTheme.Spacing.md)
    }
}
