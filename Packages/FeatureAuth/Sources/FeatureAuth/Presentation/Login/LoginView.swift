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
    @State private var presentedLegalDocument: LegalDocumentType?

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
                .clipped()
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
        .sheet(item: $presentedLegalDocument) { documentType in
            LegalDocumentSheet(documentType: documentType)
                .environmentObject(languageService)
        }
        .onChange(of: viewModel.state) { state in
            if case .loaded(let session) = state {
                onAuthenticated?(session.user)
            }
        }
        .alert(
            languageService.text(.commonError),
            isPresented: $viewModel.showErrorAlert
        ) {
            Button(languageService.text(.commonOK), role: .cancel) {}
        } message: {
            Text(languageService.text(.authSignInFailedGeneric))
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
                        otpError: localizedOtpKey(viewModel.otpErrorKey),
                        otpInfoMessage: localizedOtpKey(viewModel.otpInfoMessageKey),
                        isLoading: viewModel.state.isLoading,
                        cornerRadius: Self.fieldCornerRadius,
                        backTitle: languageService.text(.commonBack),
                        resendTitle: languageService.text(.changePasswordResendCode),
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
                        otpError: localizedOtpKey(viewModel.otpErrorKey),
                        otpInfoMessage: localizedOtpKey(viewModel.otpInfoMessageKey),
                        isLoading: viewModel.state.isLoading,
                        cornerRadius: Self.fieldCornerRadius,
                        backTitle: languageService.text(.commonBack),
                        resendTitle: languageService.text(.changePasswordResendCode),
                        onResend: { Task { await viewModel.resendRegistrationOtp() } },
                        onSubmit: { Task { await viewModel.completeRegistration() } },
                        onBack: { viewModel.goBackFromRegisterOtp() }
                    )
                }

                if viewModel.step == .credentials {
                    credentialsLegalFooter
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

    private var credentialsLegalFooter: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            LegalLinksFooter(
                hasAcceptedTerms: $viewModel.hasAcceptedLegalTerms,
                showsConsentCheckbox: viewModel.showsRegistrationFields,
                consentPrefix: viewModel.showsRegistrationFields
                    ? .legalConsentPrefix
                    : .legalConsentPrefixSignIn,
                onOpenTerms: { presentedLegalDocument = .terms },
                onOpenPrivacy: { presentedLegalDocument = .privacy }
            )
            .onChange(of: viewModel.hasAcceptedLegalTerms) { accepted in
                if accepted {
                    viewModel.legalConsentError = nil
                }
            }

            if viewModel.legalConsentError != nil {
                Text(languageService.text(.legalConsentRequiredError))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
                    .multilineTextAlignment(.center)
            }
        }
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
            Text(languageService.text(.authLoginTagline))
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
                emailPasswordFields
                    .transition(AuthFlowMotion.credentialsFieldTransition)
            }

            if viewModel.showsRegistrationFields {
                registrationFields
                    .transition(AuthFlowMotion.credentialsFieldTransition)
            }
        }
        .animation(AuthFlowMotion.fieldReveal, value: viewModel.lookupState)
    }

    private var emailPasswordFields: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            SplickTextField(
                languageService.text(.authPassword),
                text: $viewModel.password,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock",
                cornerRadius: Self.fieldCornerRadius,
                passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
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
            .onChange(of: viewModel.username) { _ in viewModel.onUsernameChanged() }

            SplickTextField(
                languageService.text(.authDisplayNameOptional),
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
                cornerRadius: Self.fieldCornerRadius,
                passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
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
                cornerRadius: Self.fieldCornerRadius,
                passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }
        }
    }

    private var dateOfBirthField: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            Button {
                viewModel.prepareDateOfBirthPicker()
                showDateOfBirthPicker = true
            } label: {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(width: 20)

                    if let dateOfBirth = viewModel.dateOfBirth {
                        Text(Self.birthDateFormatter.string(from: dateOfBirth))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(languageService.text(.authDateOfBirthPlaceholder))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(languageService.text(.authDateOfBirthOptional))
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
                    selection: $viewModel.dateOfBirthDraft,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle(languageService.text(.authDateOfBirthOptional))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonClear)) {
                        viewModel.clearDateOfBirth()
                        showDateOfBirthPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) {
                        viewModel.confirmDateOfBirth()
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
            isLoading: viewModel.loadingAction == .credentials,
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
                    provider: .apple,
                    accessibilityLabel: languageService.text(.authSignInWithApple),
                    isLoading: viewModel.loadingAction == .apple,
                    isDisabled: !viewModel.isAppleSignInAvailable || viewModel.state.isLoading
                ) {
                    Task { await viewModel.signInWithApple() }
                }

                SocialSignInIconButton(
                    provider: .google,
                    accessibilityLabel: languageService.text(.authSignInWithGoogle),
                    isLoading: viewModel.loadingAction == .google,
                    isDisabled: !viewModel.isGoogleSignInAvailable || viewModel.state.isLoading
                ) {
                    Task { await viewModel.signInWithGoogle() }
                }
            }
        }
        .padding(.top, SplickTheme.Spacing.sm)
    }

    private func openForgotPassword() {
        forgotPasswordViewModel.identifier = viewModel.identifier
        forgotPasswordViewModel.validateIdentifierField()
        withAnimation(AuthFlowMotion.horizontalSlide) {
            showForgotPassword = true
        }
    }

    private func closeForgotPassword() {
        withAnimation(AuthFlowMotion.horizontalSlide) {
            showForgotPassword = false
        }
        forgotPasswordViewModel.reset()
    }

    private func localizedOtpKey(_ key: L10nKey?) -> String? {
        key.map { languageService.text($0) }
    }
}
