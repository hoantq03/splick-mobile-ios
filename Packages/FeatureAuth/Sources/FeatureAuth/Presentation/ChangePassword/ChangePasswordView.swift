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

    private let onPasswordChanged: ((User) -> Void)?

    public init(
        viewModel: @autoclosure @escaping () -> ChangePasswordViewModel,
        onPasswordChanged: ((User) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onPasswordChanged = onPasswordChanged
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
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
        .background(SplickTheme.Colors.background)
        .navigationTitle(languageService.text(.changePasswordTitle))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.method) { _ in
            viewModel.onMethodChanged()
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
    }

    private var verificationPicker: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.changePasswordVerifyWith))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
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

    private var currentPasswordPage: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            if viewModel.isCurrentPasswordVerified {
                verifiedNewPasswordSection
            } else {
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
                    viewModel.onCurrentPasswordChanged()
                }

                SplickButton(
                    languageService.text(.changePasswordVerifyContinue),
                    isLoading: viewModel.isVerifyingCurrentPassword,
                    isDisabled: viewModel.isVerifyingCurrentPassword
                        || viewModel.currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await viewModel.verifyCurrentPassword() }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.isCurrentPasswordVerified)
    }

    private var emailCodePage: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            if let message = viewModel.otpInfoMessage {
                Text(message)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if viewModel.isEmailCodeVerified {
                verifiedNewPasswordSection
            } else {
                SplickButton(languageService.text(.changePasswordSendCode), style: .secondary) {
                    Task { await viewModel.requestEmailCode() }
                }

                SplickOtpField(code: $viewModel.otpCode, errorMessage: viewModel.otpError)
                    .onChange(of: viewModel.otpCode) { _ in
                        viewModel.onOtpCodeChanged()
                    }

                SplickButton(
                    languageService.text(.changePasswordVerifyContinue),
                    isDisabled: viewModel.otpCode.count != SplickOtpField.defaultLength
                ) {
                    viewModel.verifyEmailCodeStep()
                }
            }
        }
        .padding(.top, SplickTheme.Spacing.sm)
    }

    private var verifiedNewPasswordSection: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            Text(languageService.text(.changePasswordVerifiedHint))
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            PasswordMascotView(
                passwordLength: viewModel.newPassword.count,
                isPasswordVisible: isNewPasswordVisible
            )
            .padding(.bottom, SplickTheme.Spacing.xs)

            SplickTextField(
                languageService.text(.changePasswordNewPassword),
                text: $viewModel.newPassword,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock",
                validationStatus: viewModel.passwordStrength.isStrong && !viewModel.newPassword.isEmpty ? .valid : .neutral,
                showsPasswordVisibilityToggle: true,
                isPasswordVisible: $isNewPasswordVisible,
                passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.newPassword) { _ in viewModel.validatePasswordField() }

            SplickTextField(
                languageService.text(.changePasswordConfirmPassword),
                text: $viewModel.confirmPassword,
                isSecure: true,
                errorMessage: viewModel.confirmPasswordError,
                icon: "lock.fill",
                validationStatus: passwordsMatchStatus,
                showsPasswordVisibilityToggle: true,
                isPasswordVisible: $isConfirmPasswordVisible,
                passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }

            if let error = viewModel.state.error {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
                    .multilineTextAlignment(.center)
            }

            SplickButton(
                languageService.text(.changePasswordUpdate),
                isLoading: viewModel.state.isLoading,
                isDisabled: submitDisabled
            ) {
                Task { await viewModel.changePassword() }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var passwordsMatchStatus: FieldValidationStatus {
        guard !viewModel.confirmPassword.isEmpty else { return .neutral }
        return viewModel.newPassword == viewModel.confirmPassword ? .valid : .neutral
    }

    private var submitDisabled: Bool {
        viewModel.state.isLoading
            || !viewModel.passwordStrength.isStrong
            || viewModel.newPassword != viewModel.confirmPassword
    }
}
