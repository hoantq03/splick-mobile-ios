import SwiftUI
import DesignSystem
import Common
import Localization

public struct AccountClosureSheet: View {
    @StateObject private var viewModel: AccountClosureSheetViewModel
    @EnvironmentObject private var languageService: LanguageService

    @State private var isPasswordVisible = false
    @State private var confirmedRevealStep = 0
    @State private var showActionConfirm = false

    @Binding private var isPresented: Bool

    public init(
        isPresented: Binding<Bool>,
        viewModel: @autoclosure @escaping () -> AccountClosureSheetViewModel
    ) {
        _isPresented = isPresented
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    warningHeader

                    if let error = viewModel.sheetError {
                        ConnectAccountSheetErrorBanner(message: error)
                    }

                    if viewModel.canUseEmailVerification {
                        verificationPicker
                    }

                    verificationSection

                    if viewModel.isVerified {
                        if confirmedRevealStep >= 1 {
                            Text(languageService.text(.accountClosureVerifiedHint))
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .transition(confirmedTransition)
                        }

                        if confirmedRevealStep >= 2 {
                            SplickButton(
                                confirmButtonTitle,
                                style: viewModel.action == .delete ? .destructive : .primary,
                                isLoading: viewModel.isExecuting,
                                isFailed: viewModel.sheetError != nil
                            ) {
                                hideKeyboard()
                                showActionConfirm = true
                            }
                            .transition(confirmedTransition)
                        }
                    }
                }
                .padding(SplickTheme.Spacing.lg)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: viewModel.isVerified)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .dismissKeyboardOnTap()
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                viewModel.reset()
                confirmedRevealStep = 0
            }
            .onChange(of: viewModel.method) { _ in
                viewModel.onMethodChanged()
                confirmedRevealStep = 0
            }
            .onChange(of: viewModel.isVerified) { verified in
                if verified {
                    animateConfirmedReveal()
                } else {
                    confirmedRevealStep = 0
                }
            }
            .alert(
                actionConfirmTitle,
                isPresented: $showActionConfirm
            ) {
                Button(languageService.text(.commonCancel), role: .cancel) {}
                Button(confirmButtonTitle, role: .destructive) {
                    Task {
                        let success = await viewModel.executeAction()
                        if success {
                            isPresented = false
                        }
                    }
                }
            } message: {
                Text(actionConfirmMessage)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var verificationSection: some View {
        switch viewModel.method {
        case .password:
            passwordVerificationSection
        case .emailCode:
            emailCodeVerificationSection
        }
    }

    private var verificationPicker: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.changePasswordVerifyWith))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.leading, SplickTheme.Spacing.sm)

            Picker("", selection: $viewModel.method) {
                Text(languageService.text(.changePasswordMethodCurrent))
                    .tag(AccountClosureSheetViewModel.VerificationMethod.password)
                Text(languageService.text(.changePasswordMethodEmail))
                    .tag(AccountClosureSheetViewModel.VerificationMethod.emailCode)
            }
            .pickerStyle(.segmented)
        }
    }

    private var passwordVerificationSection: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            SplickTextField(
                languageService.text(.changePasswordCurrentPassword),
                text: $viewModel.password,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock",
                showsPasswordVisibilityToggle: true,
                isPasswordVisible: $isPasswordVisible,
                passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
            )
            .textContentType(.password)
            .onChange(of: viewModel.password) { _ in
                viewModel.onPasswordChanged()
            }

            if !viewModel.isVerified {
                SplickButton(
                    languageService.text(.changePasswordVerifyContinue),
                    isLoading: viewModel.isVerifying,
                    isFailed: viewModel.passwordError != nil,
                    isDisabled: viewModel.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    hideKeyboard()
                    Task { await viewModel.verifyIdentity() }
                }
            }
        }
    }

    private var emailCodeVerificationSection: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            ConnectAccountReadOnlyField(
                label: languageService.text(.changePasswordEmailHint),
                value: viewModel.accountEmail,
                icon: "envelope.fill"
            )

            if !viewModel.isVerified {
                if !viewModel.hasSentEmailCode {
                    SplickButton(
                        languageService.text(.changePasswordSendCode),
                        isLoading: viewModel.isRequestingEmailCode,
                        isFailed: viewModel.sendCodeFailed
                    ) {
                        hideKeyboard()
                        Task { await viewModel.requestEmailCode() }
                    }
                } else {
                    if let info = viewModel.otpInfoMessage {
                        Text(info)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    SplickOtpField(code: $viewModel.otpCode, errorMessage: viewModel.otpError)
                        .onChange(of: viewModel.otpCode) { _ in
                            viewModel.onOtpCodeChanged()
                        }

                    resendCodeControl

                    SplickButton(
                        languageService.text(.changePasswordVerifyContinue),
                        isLoading: viewModel.isVerifying,
                        isFailed: viewModel.otpError != nil,
                        isDisabled: viewModel.otpCode.count != SplickOtpField.defaultLength
                    ) {
                        hideKeyboard()
                        Task { await viewModel.verifyIdentity() }
                    }
                }
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
        }
    }

    private var warningHeader: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(warningTint.opacity(0.14))
                    .frame(width: 56, height: 56)

                Image(systemName: warningIconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(warningTint)
                    .symbolRenderingMode(.hierarchical)
            }

            Text(warningMessage)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SplickTheme.Spacing.sm)
    }

    private var sheetTitle: String {
        switch viewModel.action {
        case .deactivate:
            return languageService.text(.profileDeactivate)
        case .delete:
            return languageService.text(.profileDeleteAccount)
        }
    }

    private var warningMessage: String {
        switch viewModel.action {
        case .deactivate:
            return languageService.text(.accountClosureDeactivateWarning)
        case .delete:
            return languageService.text(.accountClosureDeleteWarning)
        }
    }

    private var confirmButtonTitle: String {
        switch viewModel.action {
        case .deactivate:
            return languageService.text(.accountClosureConfirmDeactivate)
        case .delete:
            return languageService.text(.accountClosureConfirmDelete)
        }
    }

    private var warningIconName: String {
        switch viewModel.action {
        case .deactivate:
            return "pause.circle.fill"
        case .delete:
            return "trash.fill"
        }
    }

    private var warningTint: Color {
        SplickTheme.Colors.brandBlue
    }

    private var actionConfirmTitle: String {
        switch viewModel.action {
        case .deactivate:
            return languageService.text(.accountClosureDeactivateConfirmTitle)
        case .delete:
            return languageService.text(.accountClosureDeleteConfirmTitle)
        }
    }

    private var actionConfirmMessage: String {
        switch viewModel.action {
        case .deactivate:
            return languageService.text(.accountClosureDeactivateConfirmMessage)
        case .delete:
            return languageService.text(.accountClosureDeleteConfirmMessage)
        }
    }

    private var confirmedTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    private func animateConfirmedReveal() {
        confirmedRevealStep = 0
        Task { @MainActor in
            for step in 1...2 {
                try? await Task.sleep(nanoseconds: 55_000_000)
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    confirmedRevealStep = step
                }
            }
        }
    }
}
