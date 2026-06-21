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
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.lg) {
                if presentation == .inline {
                    inlineHeader
                }

                switch viewModel.step {
                case .identifier:
                    identifierStep
                case .reset:
                    resetStep
                }

                if let error = viewModel.state.error {
                    Text(error)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .padding(.top, presentation == .inline ? SplickTheme.Spacing.md : SplickTheme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SplickTheme.Colors.background)
    }

    private var inlineHeader: some View {
        HStack {
            Button {
                onBack?()
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
                errorMessage: viewModel.identifierError,
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
                isLoading: viewModel.state.isLoading,
                isDisabled: viewModel.identifier.trimmed.isEmpty,
                cornerRadius: fieldCornerRadius
            ) {
                Task { await viewModel.requestResetCode() }
            }
        }
    }

    private var resetStep: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            VStack(spacing: SplickTheme.Spacing.xs) {
                Text(languageService.text(.authVerifyEmailTitle))
                    .font(SplickTheme.Typography.title)
                Text(
                    String(
                        format: languageService.text(.authVerifyEmailSubtitle),
                        viewModel.identifier.trimmed
                    )
                )
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            }

            if let otpInfoMessage = viewModel.otpInfoMessage {
                Text(otpInfoMessage)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SplickOtpField(
                code: $viewModel.otpCode,
                errorMessage: viewModel.otpError,
                cornerRadius: fieldCornerRadius
            )

            Button(languageService.text(.authSendCode)) {
                Task { await viewModel.resendCode() }
            }
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)

            Button(languageService.text(.authUseDifferentIdentifier)) {
                viewModel.goBackToIdentifier()
            }
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)

            SplickTextField(
                languageService.text(.authPassword),
                text: $viewModel.password,
                isSecure: true,
                errorMessage: viewModel.passwordError,
                icon: "lock",
                cornerRadius: fieldCornerRadius
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.password) { _ in viewModel.validatePasswordField() }

            SplickTextField(
                languageService.text(.authConfirmPassword),
                text: $viewModel.confirmPassword,
                isSecure: true,
                errorMessage: viewModel.confirmPasswordError,
                icon: "lock.fill",
                cornerRadius: fieldCornerRadius
            )
            .textContentType(.newPassword)
            .onChange(of: viewModel.confirmPassword) { _ in viewModel.validateConfirmPasswordField() }

            SplickButton(
                languageService.text(.authResetPasswordTitle),
                isLoading: viewModel.state.isLoading,
                isDisabled: resetSubmitDisabled,
                cornerRadius: fieldCornerRadius
            ) {
                Task { await viewModel.resetPassword() }
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
        viewModel.otpCode.count != 6
            || !viewModel.passwordStrength.isStrong
            || viewModel.password != viewModel.confirmPassword
    }
}
