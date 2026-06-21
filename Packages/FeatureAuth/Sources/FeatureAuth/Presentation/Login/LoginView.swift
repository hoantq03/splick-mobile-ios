import SwiftUI
import UIKit
import DesignSystem
import Common
import Localization
import SplickDomain

public struct LoginView: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var viewModel: LoginViewModel
    @StateObject private var forgotPasswordViewModel: ForgotPasswordViewModel
    private let onAuthenticated: ((User) -> Void)?
    @State private var showForgotPassword = false
    @State private var showDateOfBirthPicker = false

    private static let fieldCornerRadius = SplickTheme.CornerRadius.pill

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    public init(
        viewModel: @autoclosure @escaping () -> LoginViewModel,
        forgotPasswordViewModelFactory: @escaping () -> ForgotPasswordViewModel,
        onAuthenticated: ((User) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        _forgotPasswordViewModel = StateObject(wrappedValue: forgotPasswordViewModelFactory())
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                signInPanel
                    .frame(width: geometry.size.width)

                ForgotPasswordView(
                    viewModel: forgotPasswordViewModel,
                    presentation: .inline,
                    fieldCornerRadius: Self.fieldCornerRadius,
                    onBack: { closeForgotPassword() },
                    onAuthenticated: onAuthenticated
                )
                .frame(width: geometry.size.width)
            }
            .offset(x: showForgotPassword ? -geometry.size.width : 0)
            .animation(AuthFlowMotion.horizontalSlide, value: showForgotPassword)
            .frame(width: geometry.size.width, alignment: .leading)
            .clipped()
        }
        .background(SplickTheme.Colors.background)
        .sheet(isPresented: $viewModel.showPasswordRequirements) {
            PasswordRequirementsSheet(result: viewModel.passwordStrength)
        }
        .sheet(isPresented: $showDateOfBirthPicker) {
            dateOfBirthPickerSheet
        }
        .onChange(of: viewModel.state) { state in
            if case .loaded(let session) = state {
                onAuthenticated?(session.user)
            }
        }
    }

    private var signInPanel: some View {
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
                        title: languageService.text(.authVerifyPhoneTitle),
                        subtitle: String(
                            format: languageService.text(.authVerifyPhoneSubtitle),
                            viewModel.phoneNumber
                        ),
                        submitTitle: languageService.text(.authSignIn),
                        otpError: viewModel.otpError,
                        otpInfoMessage: viewModel.otpInfoMessage,
                        isLoading: viewModel.state.isLoading,
                        cornerRadius: Self.fieldCornerRadius,
                        onResend: { Task { await viewModel.resendPhoneOtp() } },
                        onSubmit: { Task { await viewModel.verifyPhoneOtp() } },
                        onBack: { viewModel.goBackToCredentials() }
                    )
                case .registerOtp:
                    OtpVerificationView(
                        otpCode: $viewModel.otpCode,
                        title: registerOtpTitle,
                        subtitle: registerOtpSubtitle,
                        submitTitle: languageService.text(.authSignUp),
                        otpError: viewModel.otpError,
                        otpInfoMessage: viewModel.otpInfoMessage,
                        isLoading: viewModel.state.isLoading,
                        cornerRadius: Self.fieldCornerRadius,
                        onResend: { Task { await viewModel.resendRegistrationOtp() } },
                        onSubmit: { Task { await viewModel.completeRegistration() } },
                        onBack: { viewModel.goBackFromRegisterOtp() }
                    )
                }

                if viewModel.step == .credentials, let error = viewModel.state.error {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }

                if viewModel.step == .credentials, showsSocialSignIn {
                    socialSignInSection
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .padding(.top, SplickTheme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var showsSocialSignIn: Bool {
        viewModel.step == .credentials && !viewModel.showsRegistrationFields
    }

    private var registerOtpTitle: String {
        viewModel.detectedKind == .email
            ? languageService.text(.authVerifyEmailTitle)
            : languageService.text(.authVerifyPhoneTitle)
    }

    private var registerOtpSubtitle: String {
        switch viewModel.detectedKind {
        case .email:
            return String(
                format: languageService.text(.authVerifyEmailSubtitle),
                viewModel.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        case .phone:
            return String(
                format: languageService.text(.authVerifyPhoneSubtitle),
                viewModel.phoneNumber
            )
        case .unknown:
            return ""
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
            SplickTextField(
                languageService.text(.authIdentifier),
                text: $viewModel.identifier,
                errorMessage: viewModel.identifierError,
                icon: identifierIcon,
                validationStatus: viewModel.identifierStatus,
                cornerRadius: Self.fieldCornerRadius
            )
            .textContentType(identifierTextContentType)
            .keyboardType(identifierKeyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: viewModel.identifier) { _ in
                viewModel.onIdentifierChanged()
            }

            if viewModel.showsPasswordField {
                SplickTextField(
                    languageService.text(.authPassword),
                    text: $viewModel.password,
                    isSecure: true,
                    errorMessage: viewModel.passwordError,
                    icon: "lock",
                    cornerRadius: Self.fieldCornerRadius
                )
                .textContentType(.password)

                if viewModel.showsForgotPassword {
                    HStack {
                        Spacer()
                        Button(languageService.text(.authForgotPassword)) {
                            openForgotPassword()
                        }
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                }
            }

            if viewModel.showsRegistrationFields {
                registrationFields
            }
        }
    }

    private var registrationFields: some View {
        Group {
            SplickTextField(
                languageService.text(.authUsername),
                text: $viewModel.username,
                errorMessage: viewModel.usernameError,
                icon: "person",
                validationStatus: viewModel.usernameStatus,
                cornerRadius: Self.fieldCornerRadius
            )
            .textContentType(.username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: viewModel.username) { _ in viewModel.validateUsernameField() }

            SplickTextField(
                languageService.text(.authDisplayName),
                text: $viewModel.displayName,
                errorMessage: viewModel.displayNameError,
                icon: "textformat",
                cornerRadius: Self.fieldCornerRadius
            )
            .textContentType(.name)
            .onChange(of: viewModel.displayName) { _ in viewModel.validateDisplayNameField() }

            dateOfBirthField

            SplickTextField(
                languageService.text(.authPassword),
                text: $viewModel.password,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock",
                validationStatus: viewModel.passwordStatus,
                onValidationAccessoryTap: { viewModel.showPasswordRequirements = true },
                cornerRadius: Self.fieldCornerRadius
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.password) { _ in viewModel.validatePasswordField() }

            SplickTextField(
                languageService.text(.authConfirmPassword),
                text: $viewModel.confirmPassword,
                isSecure: true,
                errorMessage: viewModel.confirmPasswordError,
                icon: "lock.fill",
                validationStatus: viewModel.confirmPasswordStatus,
                cornerRadius: Self.fieldCornerRadius
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }
        }
    }

    private var dateOfBirthField: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            Button {
                showDateOfBirthPicker = true
            } label: {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(width: 20)

                    Text(Self.birthDateFormatter.string(from: viewModel.dateOfBirth))
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(languageService.text(.authDateOfBirth))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .padding(SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Self.fieldCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Self.fieldCornerRadius, style: .continuous)
                        .strokeBorder(
                            viewModel.dateOfBirthError != nil ? SplickTheme.Colors.error : Color.clear,
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)

            if let error = viewModel.dateOfBirthError {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
    }

    private var dateOfBirthPickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    languageService.text(.authDateOfBirth),
                    selection: $viewModel.dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle(languageService.text(.authDateOfBirth))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) {
                        viewModel.validateDateOfBirthField()
                        showDateOfBirthPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var identifierIcon: String {
        switch viewModel.detectedKind {
        case .email: return "envelope"
        case .phone: return "phone"
        case .unknown: return "person"
        }
    }

    private var identifierKeyboardType: UIKeyboardType {
        switch viewModel.detectedKind {
        case .phone: return .phonePad
        case .email, .unknown: return .emailAddress
        }
    }

    private var identifierTextContentType: UITextContentType {
        switch viewModel.detectedKind {
        case .phone: return .telephoneNumber
        case .email, .unknown: return .username
        }
    }

    private var credentialsActions: some View {
        SplickButton(
            languageService.text(viewModel.submitTitleKey),
            isLoading: viewModel.state.isLoading,
            isDisabled: viewModel.credentialsSubmitDisabled,
            cornerRadius: Self.fieldCornerRadius
        ) {
            Task { await viewModel.submit() }
        }
    }

    private var socialSignInSection: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            HStack {
                Rectangle()
                    .fill(SplickTheme.Colors.textSecondary.opacity(0.35))
                    .frame(height: 1)
                Text(languageService.text(.commonOr))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                Rectangle()
                    .fill(SplickTheme.Colors.textSecondary.opacity(0.35))
                    .frame(height: 1)
            }

            HStack(spacing: SplickTheme.Spacing.lg) {
                SocialSignInIconButton(
                    provider: .google,
                    accessibilityLabel: languageService.text(.authSignInWithGoogle),
                    isLoading: viewModel.state.isLoading,
                    isDisabled: !viewModel.isGoogleSignInAvailable || viewModel.state.isLoading
                ) {
                    Task { await viewModel.signInWithGoogle() }
                }

                SocialSignInIconButton(
                    provider: .facebook,
                    accessibilityLabel: languageService.text(.authSignInWithFacebook),
                    isDisabled: viewModel.state.isLoading
                ) {
                    viewModel.state = .failed(languageService.text(.authFacebookComingSoon))
                }
            }
        }
        .padding(.top, SplickTheme.Spacing.sm)
    }

    private func openForgotPassword() {
        withAnimation(AuthFlowMotion.horizontalSlide) {
            showForgotPassword = true
        }
    }

    private func closeForgotPassword() {
        withAnimation(AuthFlowMotion.horizontalSlide) {
            showForgotPassword = false
        }
    }
}
