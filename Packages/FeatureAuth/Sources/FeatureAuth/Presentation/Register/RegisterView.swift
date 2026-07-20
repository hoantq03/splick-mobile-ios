import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

public struct RegisterView: View {
    @EnvironmentObject private var languageService: LanguageService
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
                case .otpVerification:
                    OtpVerificationView(
                        otpCode: $viewModel.otpCode,
                        title: otpTitle,
                        subtitle: otpSubtitle,
                        submitTitle: languageService.text(.authCreateAccountTitle),
                        otpError: viewModel.otpError,
                        otpInfoMessage: viewModel.otpInfoMessage,
                        isLoading: viewModel.state.isLoading,
                        backTitle: languageService.text(.commonBack),
                        resendTitle: languageService.text(.changePasswordResendCode),
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

    private var otpTitle: String {
        viewModel.channel == .email
            ? languageService.text(.authVerifyEmailTitle)
            : languageService.text(.authVerifyPhoneTitle)
    }

    private var otpSubtitle: String {
        switch viewModel.channel {
        case .email:
            return String(format: languageService.text(.authVerifyEmailSubtitle), viewModel.email)
        case .phone:
            return String(format: languageService.text(.authVerifyPhoneSubtitle), viewModel.phoneNumber)
        }
    }

    private var headerSection: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.authCreateAccountTitle))
                .font(SplickTheme.Typography.largeTitle)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            Text(headerSubtitle)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .padding(.bottom, SplickTheme.Spacing.md)
    }

    private var headerSubtitle: String {
        switch viewModel.step {
        case .accountDetails:
            return languageService.text(.authRegisterSubtitle)
        case .otpVerification:
            return otpTitle
        }
    }

    private var accountDetailsSection: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            AuthMethodPicker(
                selection: $viewModel.channel,
                methods: AuthRegistrationChannel.allCases,
                title: { $0.title }
            )

            switch viewModel.channel {
            case .email:
                SplickTextField(
                    languageService.text(.authEmail),
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

            case .phone:
                SplickTextField(
                    languageService.text(.connectedAccountsPhoneField),
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

            SplickTextField(
                languageService.text(.authUsername),
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
                languageService.text(.authDisplayName),
                text: $viewModel.displayName,
                icon: "textformat"
            )
            .textContentType(.name)

            SplickTextField(
                languageService.text(.authPassword),
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
                languageService.text(.authConfirmPassword),
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
            languageService.text(.authContinue),
            isLoading: viewModel.state.isLoading,
            isDisabled: !viewModel.canContinueAccountDetails
        ) {
            Task { await viewModel.requestOtpAndContinue() }
        }
    }
}
