import Foundation
import SwiftUI
import Common
import DesignSystem
import SplickDomain

@MainActor
public final class ForgotPasswordViewModel: ObservableObject {
    enum Step {
        case identifier
        case reset
    }

    @Published var step: Step = .identifier
    @Published var identifier = ""
    @Published var otpCode = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var identifierError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    @Published var otpError: String?
    @Published var otpInfoMessage: String?
    @Published var state: LoadingState<AuthSession> = .idle
    @Published var passwordStrength: PasswordStrengthResult = .empty

    @Published private(set) var identifierStatus: FieldValidationStatus = .neutral

    private let forgotPasswordUseCase: ForgotPasswordUseCaseProtocol
    private let resetPasswordUseCase: ResetPasswordUseCaseProtocol

    var detectedKind: LoginIdentifierKind {
        identifier.detectedLoginIdentifierKind
    }

    var normalizedEmail: String {
        identifier.trimmed
    }

    public init(
        forgotPasswordUseCase: ForgotPasswordUseCaseProtocol,
        resetPasswordUseCase: ResetPasswordUseCaseProtocol
    ) {
        self.forgotPasswordUseCase = forgotPasswordUseCase
        self.resetPasswordUseCase = resetPasswordUseCase
    }

    func validateIdentifierField() {
        let value = identifier.trimmed
        if value.isEmpty {
            identifierError = nil
            identifierStatus = .neutral
            return
        }

        switch detectedKind {
        case .email:
            identifierError = nil
            identifierStatus = .valid
        case .phone:
            identifierError = nil
            identifierStatus = .valid
        case .unknown:
            identifierError = value.contains("@")
                ? "Please enter a valid email"
                : "Use international format, e.g. +84901234567"
            identifierStatus = .neutral
        }
    }

    func validatePasswordField() {
        passwordStrength = PasswordStrengthValidator.evaluate(password)
        if password.isEmpty {
            passwordError = nil
            return
        }
        passwordError = passwordStrength.isStrong ? nil : "Password does not meet requirements"
        validateConfirmPasswordField()
    }

    func validateConfirmPasswordField() {
        if confirmPassword.isEmpty {
            confirmPasswordError = nil
            return
        }
        confirmPasswordError = password == confirmPassword ? nil : "Passwords do not match"
    }

    func requestResetCode() async {
        validateIdentifierField()
        guard identifierError == nil, detectedKind != .unknown else { return }

        guard detectedKind == .email else {
            state = .failed("Password reset via phone is not available yet. Use your email address.")
            return
        }

        let normalized = normalizedEmail
        guard !normalized.isEmpty else { return }

        state = .loading
        do {
            try await forgotPasswordUseCase.execute(email: normalized)
            step = .reset
            otpInfoMessage = "If an account exists for this email, a code was sent. Check your inbox."
            state = .idle
        } catch let error as AuthError {
            applyAuthError(error, onOtpStep: false)
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("Could not send reset code. Please try again.")
        }
    }

    func resetPassword() async {
        validatePasswordField()
        validateConfirmPasswordField()
        guard passwordStrength.isStrong, password == confirmPassword else { return }

        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6 else {
            otpError = "Enter the 6-digit code"
            return
        }
        otpError = nil

        state = .loading
        do {
            let session = try await resetPasswordUseCase.execute(
                email: normalizedEmail,
                otpCode: code,
                newPassword: password
            )
            state = .loaded(session)
        } catch let error as AuthError {
            applyAuthError(error, onOtpStep: true)
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("Could not reset password. Please try again.")
        }
    }

    func resendCode() async {
        await requestResetCode()
    }

    func goBackToIdentifier() {
        step = .identifier
        otpCode = ""
        password = ""
        confirmPassword = ""
        otpError = nil
        otpInfoMessage = nil
        state = .idle
    }

    private func applyAuthError(_ error: AuthError, onOtpStep: Bool) {
        if onOtpStep && error.shouldShowOnOtpStep {
            otpError = error.userMessage
            state = .idle
        } else {
            state = .failed(error.userMessage)
        }
    }
}
