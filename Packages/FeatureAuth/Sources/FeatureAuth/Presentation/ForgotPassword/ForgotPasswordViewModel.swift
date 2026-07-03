import Foundation
import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

@MainActor
public final class ForgotPasswordViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case identifier = 0
        case otp = 1
        case newPassword = 2
    }

    static let resendCooldownSeconds = 60

    @Published var step: Step = .identifier
    @Published var identifier = ""
    @Published var otpCode = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var identifierErrorKey: L10nKey?
    @Published var passwordErrorKey: L10nKey?
    @Published var confirmPasswordErrorKey: L10nKey?
    @Published var otpErrorKey: L10nKey?
    @Published var otpInfoMessageKey: L10nKey?
    @Published var state: LoadingState<AuthSession> = .idle
    @Published var passwordStrength: PasswordStrengthResult = .empty
    @Published var showErrorAlert = false
    @Published private(set) var resendCooldownRemaining = 0

    @Published private(set) var identifierStatus: FieldValidationStatus = .neutral
    @Published private(set) var isOtpVerified = false

    private let forgotPasswordUseCase: ForgotPasswordUseCaseProtocol
    private let verifyResetPasswordOtpUseCase: VerifyResetPasswordOtpUseCaseProtocol
    private let resetPasswordUseCase: ResetPasswordUseCaseProtocol
    private var resendCooldownTask: Task<Void, Never>?

    var detectedKind: LoginIdentifierKind {
        identifier.detectedLoginIdentifierKind
    }

    var normalizedEmail: String {
        identifier.trimmed.lowercased()
    }

    var canResendCode: Bool {
        resendCooldownRemaining == 0 && !state.isLoading
    }

    public init(
        forgotPasswordUseCase: ForgotPasswordUseCaseProtocol,
        verifyResetPasswordOtpUseCase: VerifyResetPasswordOtpUseCaseProtocol,
        resetPasswordUseCase: ResetPasswordUseCaseProtocol
    ) {
        self.forgotPasswordUseCase = forgotPasswordUseCase
        self.verifyResetPasswordOtpUseCase = verifyResetPasswordOtpUseCase
        self.resetPasswordUseCase = resetPasswordUseCase
    }

    deinit {
        resendCooldownTask?.cancel()
    }

    func reset() {
        resendCooldownTask?.cancel()
        resendCooldownRemaining = 0
        step = .identifier
        identifier = ""
        otpCode = ""
        password = ""
        confirmPassword = ""
        identifierErrorKey = nil
        passwordErrorKey = nil
        confirmPasswordErrorKey = nil
        otpErrorKey = nil
        otpInfoMessageKey = nil
        identifierStatus = .neutral
        isOtpVerified = false
        passwordStrength = .empty
        showErrorAlert = false
        state = .idle
    }

    func validateIdentifierField() {
        let value = identifier.trimmed
        if value.isEmpty {
            identifierErrorKey = nil
            identifierStatus = .neutral
            return
        }

        switch detectedKind {
        case .email, .phone:
            identifierErrorKey = nil
            identifierStatus = .valid
        case .unknown:
            identifierErrorKey = value.contains("@")
                ? .authValidationInvalidEmail
                : .authValidationInvalidPhone
            identifierStatus = .neutral
        }
    }

    func validatePasswordField() {
        passwordStrength = PasswordStrengthValidator.evaluate(password)
        if password.isEmpty {
            passwordErrorKey = nil
            validateConfirmPasswordField()
            return
        }
        passwordErrorKey = passwordStrength.isStrong ? nil : .changePasswordWeakPassword
        validateConfirmPasswordField()
    }

    func validateConfirmPasswordField() {
        if confirmPassword.isEmpty {
            confirmPasswordErrorKey = nil
            return
        }
        confirmPasswordErrorKey = password == confirmPassword ? nil : .changePasswordPasswordsMismatch
    }

    func requestResetCode() async {
        validateIdentifierField()
        guard identifierErrorKey == nil, detectedKind != .unknown else { return }

        guard detectedKind == .email else {
            identifierErrorKey = .authForgotPasswordPhoneUnsupported
            return
        }

        let normalized = normalizedEmail
        guard !normalized.isEmpty else { return }

        setState(.loading)
        do {
            try await forgotPasswordUseCase.execute(email: normalized)
            otpCode = ""
            otpErrorKey = nil
            isOtpVerified = false
            otpInfoMessageKey = .authOtpEmailHint
            step = .otp
            startResendCooldown()
            setState(.idle)
        } catch let error as AuthError {
            applyAuthError(error, onOtpStep: false)
        } catch let error as NetworkError {
            presentGenericError(error.userMessage)
        } catch {
            presentGenericError("Could not send reset code")
        }
    }

    func verifyResetCode() async {
        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6 else {
            otpErrorKey = .changePasswordOtpRequired
            return
        }
        otpErrorKey = nil

        setState(.loading)
        do {
            try await verifyResetPasswordOtpUseCase.execute(email: normalizedEmail, otpCode: code)
            isOtpVerified = true
            step = .newPassword
            setState(.idle)
        } catch let error as AuthError {
            applyAuthError(error, onOtpStep: true)
        } catch let error as NetworkError {
            presentGenericError(error.userMessage)
        } catch {
            presentGenericError("Could not verify code")
        }
    }

    func resetPassword() async {
        guard isOtpVerified else { return }

        validatePasswordField()
        validateConfirmPasswordField()
        guard passwordStrength.isStrong, password == confirmPassword else { return }

        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6 else {
            otpErrorKey = .changePasswordOtpRequired
            step = .otp
            isOtpVerified = false
            return
        }

        setState(.loading)
        do {
            let session = try await resetPasswordUseCase.execute(
                email: normalizedEmail,
                otpCode: code,
                newPassword: password
            )
            setState(.loaded(session))
        } catch let error as AuthError {
            applyAuthError(error, onOtpStep: true)
        } catch let error as NetworkError {
            presentGenericError(error.userMessage)
        } catch {
            presentGenericError("Could not reset password")
        }
    }

    func resendCode() async {
        guard canResendCode else { return }
        await requestResetCode()
    }

    func goBackToIdentifier() {
        resendCooldownTask?.cancel()
        resendCooldownRemaining = 0
        step = .identifier
        otpCode = ""
        password = ""
        confirmPassword = ""
        otpErrorKey = nil
        otpInfoMessageKey = nil
        isOtpVerified = false
        state = .idle
    }

    func goBackToOtp() {
        step = .otp
        password = ""
        confirmPassword = ""
        passwordErrorKey = nil
        confirmPasswordErrorKey = nil
        passwordStrength = .empty
        isOtpVerified = false
    }

    private func startResendCooldown() {
        resendCooldownTask?.cancel()
        resendCooldownRemaining = Self.resendCooldownSeconds
        resendCooldownTask = Task {
            while resendCooldownRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                resendCooldownRemaining -= 1
            }
        }
    }

    private func setState(_ newState: LoadingState<AuthSession>) {
        switch newState {
        case .failed(let detail):
            presentGenericError(detail)
        default:
            state = newState
        }
    }

    private func presentGenericError(_ detail: String) {
        Log.warning("Forgot password failed: \(detail)", category: .auth)
        showErrorAlert = true
        state = .idle
    }

    private func applyAuthError(_ error: AuthError, onOtpStep: Bool) {
        if onOtpStep && error.shouldShowOnOtpStep {
            otpErrorKey = .errorAuthInvalidOtpDefault
            state = .idle
        } else {
            presentGenericError(error.userMessage)
        }
    }
}
