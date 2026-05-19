import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    private let registerViewModelFactory: () -> RegisterViewModel
    private let onAuthenticated: ((User) -> Void)?

    public init(
        viewModel: @autoclosure @escaping () -> LoginViewModel,
        registerViewModelFactory: @escaping () -> RegisterViewModel,
        onAuthenticated: ((User) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.registerViewModelFactory = registerViewModelFactory
        self.onAuthenticated = onAuthenticated
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
        .navigationDestination(isPresented: $viewModel.showRegistration) {
            RegisterView(
                viewModel: registerViewModelFactory(),
                onAuthenticated: onAuthenticated
            )
        }
        .onChange(of: viewModel.state) { state in
            if case .loaded(let session) = state {
                onAuthenticated?(session.user)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            SplickLogoMark(size: 96, layout: .markOnly, style: .fullColor)
            Text("Splick")
                .font(SplickTheme.Typography.largeTitle)
                .foregroundStyle(SplickTheme.Colors.primaryGradient)
            Text("Click moments, Split bills, Keep relations.")
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
                isDisabled: !AppConstants.Dev.useMockData
                    && (viewModel.email.isEmpty || viewModel.password.isEmpty)
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
