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

                switch viewModel.step {
                case .credentials:
                    credentialsSection
                    credentialsActions
                case .phoneOtp:
                    OtpVerificationView(
                        otpCode: $viewModel.otpCode,
                        title: "Verify your phone",
                        subtitle: "Enter the code sent to \(viewModel.phoneNumber)",
                        submitTitle: "Sign In",
                        otpError: viewModel.otpError,
                        otpInfoMessage: viewModel.otpInfoMessage,
                        isLoading: viewModel.state.isLoading,
                        onResend: { Task { await viewModel.resendPhoneOtp() } },
                        onSubmit: { Task { await viewModel.verifyPhoneOtp() } },
                        onBack: { viewModel.goBackToCredentials() }
                    )
                }

                if viewModel.step == .credentials, let error = viewModel.state.error {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }

                if viewModel.step == .credentials {
                    footerSection
                }
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

    private var credentialsSection: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            AuthMethodPicker(
                selection: $viewModel.signInMethod,
                methods: AuthSignInMethod.allCases,
                title: { $0.title }
            )

            switch viewModel.signInMethod {
            case .email:
                emailCredentialsForm
            case .phone:
                phoneCredentialsForm
            }
        }
    }

    private var emailCredentialsForm: some View {
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

    private var phoneCredentialsForm: some View {
        SplickTextField(
            "Phone number",
            text: $viewModel.phoneNumber,
            errorMessage: viewModel.phoneError,
            icon: "phone",
            validationStatus: viewModel.phoneStatus
        )
        .textContentType(.telephoneNumber)
        .keyboardType(.phonePad)
        .autocorrectionDisabled()
        .onChange(of: viewModel.phoneNumber) { _ in viewModel.validatePhoneField() }
    }

    private var credentialsActions: some View {
        SplickButton(
            viewModel.signInMethod == .email ? "Sign In" : "Send code",
            isLoading: viewModel.state.isLoading,
            isDisabled: credentialsSubmitDisabled
        ) {
            Task {
                switch viewModel.signInMethod {
                case .email:
                    await viewModel.login()
                case .phone:
                    await viewModel.requestPhoneOtpAndContinue()
                }
            }
        }
    }

    private var credentialsSubmitDisabled: Bool {
        switch viewModel.signInMethod {
        case .email:
            return viewModel.email.isEmpty || viewModel.password.isEmpty
        case .phone:
            return viewModel.phoneNumber.isEmpty || viewModel.phoneError != nil
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
