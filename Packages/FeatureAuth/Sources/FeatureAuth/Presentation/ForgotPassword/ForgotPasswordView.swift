import SwiftUI
import UIKit
import DesignSystem
import Common
import Localization
import SplickDomain

public struct ForgotPasswordView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject private var viewModel: ForgotPasswordViewModel
    @Environment(\.dismiss) private var dismiss

    private let presentation: Presentation
    private let onAuthenticated: ((User) -> Void)?
    private let onBack: (() -> Void)?
    private let fieldCornerRadius: CGFloat
    @GestureState private var stepDragOffset: CGFloat = 0

    public enum Presentation {
        case sheet
        case inline
    }

    public init(
        viewModel: ForgotPasswordViewModel,
        presentation: Presentation = .sheet,
        fieldCornerRadius: CGFloat = SplickTheme.CornerRadius.pill,
        onBack: (() -> Void)? = nil,
        onAuthenticated: ((User) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.presentation = presentation
        self.fieldCornerRadius = fieldCornerRadius
        self.onBack = onBack
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        Group {
            switch presentation {
            case .sheet:
                NavigationStack {
                    content
                        .navigationTitle(languageService.text(.authResetPasswordTitle))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(languageService.text(.commonCancel)) { dismiss() }
                            }
                        }
                }
            case .inline:
                content
            }
        }
        .clipped()
        .dismissKeyboardOnTap()
        .onChange(of: viewModel.state) { state in
            if case .loaded(let session) = state {
                onAuthenticated?(session.user)
                switch presentation {
                case .sheet:
                    dismiss()
                case .inline:
                    onBack?()
                }
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

    private var content: some View {
        VStack(spacing: 0) {
            if presentation == .inline {
                inlineHeader
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, SplickTheme.Spacing.md)
            }

            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {
                    stepScroll(identifierStep, width: geometry.size.width)
                    stepScroll(otpStep, width: geometry.size.width)
                    stepScroll(newPasswordStep, width: geometry.size.width)
                }
                .offset(x: currentStepOffset(in: geometry.size.width) + interactiveSwipeOffset(in: geometry.size.width))
                .animation(AuthFlowMotion.horizontalSlide, value: viewModel.step)
                .frame(width: geometry.size.width, alignment: .leading)
                .contentShape(Rectangle())
                .clipped()
                .simultaneousGesture(stepSwipeGesture(width: geometry.size.width))
            }
        }
        .background(SplickTheme.Colors.background)
    }

    private func stepScroll<Content: View>(_ content: Content, width: CGFloat) -> some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(width: width)
    }

    private var horizontalPadding: CGFloat {
        SplickTheme.Spacing.lg
    }

    private var inlineHeader: some View {
        HStack {
            Button {
                if viewModel.step == .identifier {
                    onBack?()
                } else if viewModel.step == .otp {
                    withAnimation(AuthFlowMotion.horizontalSlide) {
                        viewModel.goBackToIdentifier()
                    }
                } else {
                    withAnimation(AuthFlowMotion.horizontalSlide) {
                        viewModel.goBackToOtp()
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(languageService.text(.authResetPasswordTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var identifierStep: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Text(languageService.text(.authResetPasswordSubtitle))
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            SplickTextField(
                languageService.text(.authIdentifier),
                text: $viewModel.identifier,
                errorMessage: localized(viewModel.identifierErrorKey),
                icon: identifierIcon,
                validationStatus: viewModel.identifierStatus,
                cornerRadius: fieldCornerRadius
            )
            .textContentType(identifierTextContentType)
            .keyboardType(identifierKeyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: viewModel.identifier) { _ in viewModel.validateIdentifierField() }

            SplickButton(
                languageService.text(.authSendCode),
                isLoading: viewModel.state.isLoading && viewModel.step == .identifier,
                isDisabled: viewModel.identifier.trimmed.isEmpty,
                cornerRadius: fieldCornerRadius
            ) {
                Task { await viewModel.requestResetCode() }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, presentation == .inline ? SplickTheme.Spacing.md : SplickTheme.Spacing.lg)
    }

    private var otpStep: some View {
        OtpVerificationView(
            otpCode: $viewModel.otpCode,
            title: languageService.text(.authVerifyEmailTitle),
            subtitle: String(
                format: languageService.text(.authVerifyEmailSubtitle),
                viewModel.identifier.trimmed
            ),
            submitTitle: languageService.text(.changePasswordVerifyContinue),
            otpError: localized(viewModel.otpErrorKey),
            otpInfoMessage: localized(viewModel.otpInfoMessageKey),
            isLoading: viewModel.state.isLoading && viewModel.step == .otp,
            cornerRadius: fieldCornerRadius,
            showsBackButton: presentation == .sheet,
            backTitle: languageService.text(.commonBack),
            resendTitle: resendTitle,
            isResendDisabled: !viewModel.canResendCode,
            autoFocus: viewModel.step == .otp,
            onResend: { Task { await viewModel.resendCode() } },
            onSubmit: { Task { await viewModel.verifyResetCode() } },
            onBack: {
                withAnimation(AuthFlowMotion.horizontalSlide) {
                    viewModel.goBackToIdentifier()
                }
            },
            secondaryActionTitle: languageService.text(.authUseDifferentIdentifier),
            onSecondaryAction: {
                withAnimation(AuthFlowMotion.horizontalSlide) {
                    viewModel.goBackToIdentifier()
                }
            }
        )
        .padding(.horizontal, horizontalPadding)
        .padding(.top, presentation == .inline ? SplickTheme.Spacing.md : SplickTheme.Spacing.lg)
    }

    private var newPasswordStep: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            VStack(spacing: SplickTheme.Spacing.xs) {
                Text(languageService.text(.changePasswordNewPassword))
                    .font(SplickTheme.Typography.title)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(languageService.text(.changePasswordVerifiedHint))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SplickTextField(
                languageService.text(.changePasswordNewPassword),
                text: $viewModel.password,
                isSecure: true,
                errorMessage: localized(viewModel.passwordErrorKey),
                icon: "lock",
                cornerRadius: fieldCornerRadius,
                passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.password) { _ in viewModel.validatePasswordField() }

            SplickTextField(
                languageService.text(.changePasswordConfirmPassword),
                text: $viewModel.confirmPassword,
                isSecure: true,
                errorMessage: localized(viewModel.confirmPasswordErrorKey),
                icon: "lock.fill",
                cornerRadius: fieldCornerRadius,
                passwordVisibleAccessibilityLabel: languageService.text(.authShowPassword),
                passwordHiddenAccessibilityLabel: languageService.text(.authHidePassword)
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }

            SplickButton(
                languageService.text(.authResetPasswordTitle),
                isLoading: viewModel.state.isLoading && viewModel.step == .newPassword,
                isDisabled: resetSubmitDisabled,
                cornerRadius: fieldCornerRadius
            ) {
                Task { await viewModel.resetPassword() }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, presentation == .inline ? SplickTheme.Spacing.md : SplickTheme.Spacing.lg)
    }

    private var resendTitle: String {
        if viewModel.resendCooldownRemaining > 0 {
            return String(
                format: languageService.text(.changePasswordResendIn),
                viewModel.resendCooldownRemaining
            )
        }
        return languageService.text(.changePasswordResendCode)
    }

    private func localized(_ key: L10nKey?) -> String? {
        key.map { languageService.text($0) }
    }

    private func currentStepOffset(in width: CGFloat) -> CGFloat {
        -CGFloat(viewModel.step.rawValue) * width
    }

    private func interactiveSwipeOffset(in width: CGFloat) -> CGFloat {
        guard presentation == .inline, viewModel.step != .identifier else { return 0 }
        return min(max(stepDragOffset, 0), width)
    }

    private func stepSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($stepDragOffset) { value, state, _ in
                guard presentation == .inline, viewModel.step != .identifier else { return }
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard horizontal > 0, horizontal > vertical else { return }
                state = horizontal
            }
            .onEnded { value in
                guard presentation == .inline, viewModel.step != .identifier else { return }

                let threshold = width * 0.22
                let translation = value.translation.width
                let predicted = value.predictedEndTranslation.width
                guard translation > threshold || predicted > threshold * 1.4 else { return }

                withAnimation(AuthFlowMotion.horizontalSlide) {
                    switch viewModel.step {
                    case .identifier:
                        break
                    case .otp:
                        viewModel.goBackToIdentifier()
                    case .newPassword:
                        viewModel.goBackToOtp()
                    }
                }
            }
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

    private var resetSubmitDisabled: Bool {
        !viewModel.passwordStrength.isStrong || viewModel.password != viewModel.confirmPassword
    }
}
