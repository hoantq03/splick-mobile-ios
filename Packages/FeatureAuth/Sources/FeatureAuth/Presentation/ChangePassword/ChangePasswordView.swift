import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

public struct ChangePasswordView: View {
    @StateObject private var viewModel: ChangePasswordViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    @State private var isCurrentPasswordVisible = false
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var verifiedRevealStep = 0

    private let onPasswordChanged: ((User) -> Void)?

    public init(
        viewModel: @autoclosure @escaping () -> ChangePasswordViewModel,
        onPasswordChanged: ((User) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onPasswordChanged = onPasswordChanged
    }

    public var body: some View {
        Group {
            if viewModel.isResolvingPasswordLogin {
                SplickSpinner()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasPasswordLogin {
                VStack(spacing: SplickTheme.Spacing.md) {
                    verificationPicker
                        .padding(.horizontal, SplickTheme.Spacing.lg)
                        .padding(.top, SplickTheme.Spacing.lg)

                    TabView(selection: $viewModel.method) {
                        pageScroll(currentPasswordPage)
                            .tag(ChangePasswordViewModel.VerificationMethod.currentPassword)

                        pageScroll(emailCodePage)
                            .tag(ChangePasswordViewModel.VerificationMethod.emailCode)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: viewModel.method)
                }
            } else {
                ScrollView {
                    unavailableSection
                        .padding(SplickTheme.Spacing.lg)
                }
            }
        }
        .background(SplickTheme.Colors.background)
        .dismissKeyboardOnTap()
        .navigationTitle(languageService.text(.changePasswordTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadPasswordLoginState() }
        .onChange(of: viewModel.method) { _ in
            viewModel.onMethodChanged()
            verifiedRevealStep = 0
        }
        .onChange(of: viewModel.isCurrentPasswordVerified) { verified in
            if verified { animateVerifiedReveal(maxSteps: 5) } else { verifiedRevealStep = 0 }
        }
        .onChange(of: viewModel.isEmailCodeVerified) { verified in
            if verified { animateVerifiedReveal(maxSteps: 4) } else { verifiedRevealStep = 0 }
        }
        .onChange(of: viewModel.state) { state in
            if case .loaded(let session) = state {
                onPasswordChanged?(session.user)
                dismiss()
            }
        }
    }

    private func pageScroll<Content: View>(_ content: Content) -> some View {
        ScrollView {
            content
                .padding(.horizontal, SplickTheme.Spacing.lg)
                .padding(.bottom, SplickTheme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .splickAllowsOverflowingOverlays()
    }

    private var verificationPicker: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.changePasswordVerifyWith))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.leading, SplickTheme.Spacing.sm)

            Picker("", selection: $viewModel.method) {
                Text(languageService.text(.changePasswordMethodCurrent))
                    .tag(ChangePasswordViewModel.VerificationMethod.currentPassword)
                Text(languageService.text(.changePasswordMethodEmail))
                    .tag(ChangePasswordViewModel.VerificationMethod.emailCode)
            }
            .pickerStyle(.segmented)
        }
    }

    private var unavailableSection: some View {
        settingsGroup(title: languageService.text(.changePasswordTitle)) {
            Text(languageService.text(.profileChangePasswordUnavailable))
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SplickTheme.Spacing.md)
        }
    }

    private func settingsGroup<Content: View>(
        title: String,
        clipsContent: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous)
        return VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(title)
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.leading, SplickTheme.Spacing.sm)

            Group {
                if clipsContent {
                    VStack(spacing: 0) { content() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SplickTheme.Colors.cardBackground)
                        .clipShape(shape)
                } else {
                    VStack(spacing: 0) { content() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(shape.fill(SplickTheme.Colors.cardBackground))
                }
            }
        }
    }

    private var currentPasswordPage: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            if viewModel.isCurrentPasswordVerified {
                settingsGroup(title: languageService.text(.changePasswordNewPassword), clipsContent: false) {
                    verifiedNewPasswordFields()
                        .padding(SplickTheme.Spacing.md)
                }
                verifiedSubmitButton
            } else {
                settingsGroup(title: languageService.text(.changePasswordMethodCurrent), clipsContent: false) {
                    VStack(spacing: SplickTheme.Spacing.lg) {
                        PasswordMascotView(
                            passwordLength: viewModel.currentPassword.count,
                            isPasswordVisible: isCurrentPasswordVisible
                        )
                        .padding(.top, SplickTheme.Spacing.sm)
                        .padding(.bottom, SplickTheme.Spacing.xs)

                        SplickTextField(
                            languageService.text(.changePasswordCurrentPassword),
                            text: $viewModel.currentPassword,
                            isSecure: true,
                            errorMessage: viewModel.currentPasswordError,
                            icon: "lock",
                            showsPasswordVisibilityToggle: true,
                            isPasswordVisible: $isCurrentPasswordVisible,
                            passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                            passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
                        )
                        .textContentType(.password)
                        .onChange(of: viewModel.currentPassword) { _ in
                            guard !viewModel.isCurrentPasswordVerified else { return }
                            viewModel.onCurrentPasswordChanged()
                        }
                    }
                    .padding(SplickTheme.Spacing.md)
                }

                SplickButton(
                    languageService.text(.changePasswordVerifyContinue),
                    isLoading: viewModel.isVerifyingCurrentPassword,
                    isFailed: viewModel.currentPasswordError != nil,
                    isDisabled: viewModel.currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    hideKeyboard()
                    Task { await viewModel.verifyCurrentPassword() }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.isCurrentPasswordVerified)
    }

    private var emailCodePage: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            if viewModel.isEmailCodeVerified {
                settingsGroup(title: languageService.text(.changePasswordNewPassword), clipsContent: false) {
                    verifiedNewPasswordFields(showMascot: false)
                        .padding(SplickTheme.Spacing.md)
                }
                verifiedSubmitButton
            } else {
                settingsGroup(title: languageService.text(.changePasswordMethodEmail), clipsContent: false) {
                    VStack(spacing: SplickTheme.Spacing.lg) {
                        readOnlyAccountEmailField
                        emailOtpFields
                    }
                    .padding(SplickTheme.Spacing.md)
                }

                SplickButton(
                    languageService.text(
                        viewModel.hasSentEmailCode
                            ? .changePasswordVerifyContinue
                            : .changePasswordSendCode
                    ),
                    isLoading: viewModel.hasSentEmailCode
                        ? viewModel.isVerifyingEmailCode
                        : viewModel.isRequestingEmailCode,
                    isFailed: viewModel.hasSentEmailCode
                        ? viewModel.otpError != nil
                        : viewModel.sendCodeFailed,
                    isDisabled: viewModel.hasSentEmailCode
                        ? viewModel.otpCode.count != SplickOtpField.defaultLength
                        : viewModel.accountEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    if viewModel.hasSentEmailCode {
                        hideKeyboard()
                        Task { await viewModel.verifyEmailCodeStep() }
                    } else {
                        Task { await viewModel.requestEmailCode() }
                    }
                }
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: viewModel.isEmailCodeVerified)
    }

    private var readOnlyAccountEmailField: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            Text(languageService.text(.changePasswordEmailHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.leading, SplickTheme.Spacing.sm)

            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(width: 20)

                Text(viewModel.accountEmail)
                    .font(SplickTheme.Typography.body)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(SplickTheme.Colors.textSecondary.opacity(0.55))
                    .accessibilityHidden(true)
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(languageService.text(.authEmail)): \(viewModel.accountEmail)")
            .accessibilityHint(languageService.text(.changePasswordEmailHint))
        }
    }

    private var emailOtpFields: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            if let message = viewModel.otpInfoMessage {
                Text(message)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            SplickOtpField(code: $viewModel.otpCode, errorMessage: viewModel.otpError)
                .onChange(of: viewModel.otpCode) { _ in
                    guard !viewModel.isEmailCodeVerified else { return }
                    viewModel.onOtpCodeChanged()
                }

            if viewModel.hasSentEmailCode {
                resendCodeControl
            }
        }
    }

    @ViewBuilder
    private var resendCodeControl: some View {
        if viewModel.otpResendSecondsRemaining > 0 {
            Text(
                languageService.format(
                    .changePasswordResendIn,
                    viewModel.otpResendSecondsRemaining
                )
            )
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        } else {
            Button {
                Task { await viewModel.resendEmailCode() }
            } label: {
                Text(languageService.text(.changePasswordResendCode))
                    .font(SplickTheme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRequestingEmailCode)
            .opacity(viewModel.isRequestingEmailCode ? 0.5 : 1)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }
    }

    private func verifiedNewPasswordFields(showMascot: Bool = true) -> some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            if verifiedRevealStep >= 1 {
                Text(
                    languageService.text(
                        viewModel.hasPasswordLogin
                            ? .changePasswordVerifiedHint
                            : .createPasswordVerifiedHint
                    )
                )
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .transition(verifiedFieldTransition)
            }

            if showMascot, verifiedRevealStep >= 2 {
                PasswordMascotView(
                    passwordLength: viewModel.newPassword.count,
                    isPasswordVisible: isNewPasswordVisible
                )
                .padding(.bottom, SplickTheme.Spacing.xs)
                .transition(verifiedFieldTransition)
            }

            if verifiedRevealStep >= (showMascot ? 3 : 2) {
                SplickTextField(
                    languageService.text(.changePasswordNewPassword),
                    text: $viewModel.newPassword,
                    isSecure: true,
                    errorMessage: viewModel.passwordError,
                    icon: "lock",
                    validationStatus: viewModel.passwordStrength.isStrong && !viewModel.newPassword.isEmpty ? .valid : (viewModel.newPassword.isEmpty ? .neutral : .warning),
                    requirementItems: passwordRequirementGuideItems(
                        for: viewModel.newPassword,
                        languageService: languageService
                    ),
                    requirementIntro: languageService.text(.authPasswordRequirementsIntro),
                    showsPasswordVisibilityToggle: true,
                    isPasswordVisible: $isNewPasswordVisible,
                    passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                    passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
                )
                .textContentType(.newPassword)
                .onChange(of: viewModel.newPassword) { _ in viewModel.validatePasswordField() }
                .transition(verifiedFieldTransition)
            }

            if verifiedRevealStep >= (showMascot ? 4 : 3) {
                SplickTextField(
                    languageService.text(.changePasswordConfirmPassword),
                    text: $viewModel.confirmPassword,
                    isSecure: true,
                    errorMessage: nil,
                    icon: "lock.fill",
                    validationStatus: passwordsMatchStatus,
                    overlayNote: viewModel.confirmPasswordError,
                    showsPasswordVisibilityToggle: true,
                    isPasswordVisible: $isConfirmPasswordVisible,
                    passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                    passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
                )
                .textContentType(.newPassword)
                .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }
                .transition(verifiedFieldTransition)
            }

            if verifiedRevealStep >= (showMascot ? 5 : 4), let error = viewModel.state.error {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
                    .multilineTextAlignment(.center)
                    .transition(verifiedFieldTransition)
            }
        }
    }

    @ViewBuilder
    private var verifiedSubmitButton: some View {
        if verifiedRevealStep >= (viewModel.method == .currentPassword ? 5 : 4) {
            SplickButton(
                languageService.text(
                    viewModel.hasPasswordLogin ? .changePasswordUpdate : .createPasswordSubmit
                ),
                isLoading: viewModel.state.isLoading,
                isFailed: viewModel.state.error != nil,
                isDisabled: submitDisabled
            ) {
                Task { await viewModel.changePassword() }
            }
            .transition(verifiedFieldTransition)
        }
    }

    private var verifiedFieldTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    private func animateVerifiedReveal(maxSteps: Int) {
        verifiedRevealStep = 0

        Task { @MainActor in
            for step in 1...maxSteps {
                try? await Task.sleep(nanoseconds: 55_000_000)
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    verifiedRevealStep = step
                }
            }
        }
    }

    private var passwordsMatchStatus: FieldValidationStatus {
        guard !viewModel.confirmPassword.isEmpty else { return .neutral }
        return viewModel.newPassword == viewModel.confirmPassword ? .valid : .warning
    }

    private var submitDisabled: Bool {
        !viewModel.passwordStrength.isStrong
            || viewModel.newPassword != viewModel.confirmPassword
    }
}
