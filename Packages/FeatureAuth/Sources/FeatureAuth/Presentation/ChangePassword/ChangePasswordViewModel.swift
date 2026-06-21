import Foundation
import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

@MainActor
public final class ChangePasswordViewModel: ObservableObject {
    enum VerificationMethod: Hashable, CaseIterable {
        case currentPassword
        case emailCode
    }

    @Published var method: VerificationMethod = .currentPassword
    @Published var currentPassword = ""
    @Published var otpCode = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var currentPasswordError: String?
    @Published var otpError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    @Published var otpInfoMessage: String?
    @Published var state: LoadingState<AuthSession> = .idle
    @Published var passwordStrength: PasswordStrengthResult = .empty
    @Published var isCurrentPasswordVerified = false
    @Published var isEmailCodeVerified = false
    @Published var isVerifyingCurrentPassword = false

    let accountEmail: String

    private let changePasswordUseCase: ChangePasswordUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let loginUseCase: LoginUseCaseProtocol
    private let languageService: LanguageService

    public init(
        accountEmail: String,
        changePasswordUseCase: ChangePasswordUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        loginUseCase: LoginUseCaseProtocol,
        languageService: LanguageService
    ) {
        self.accountEmail = accountEmail
        self.changePasswordUseCase = changePasswordUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.loginUseCase = loginUseCase
        self.languageService = languageService
    }

    func onMethodChanged() {
        resetVerificationState()
    }

    func onCurrentPasswordChanged() {
        if isCurrentPasswordVerified {
            isCurrentPasswordVerified = false
        }
        currentPasswordError = nil
    }

    func onOtpCodeChanged() {
        if isEmailCodeVerified {
            isEmailCodeVerified = false
        }
        otpError = nil
    }

    func validatePasswordField() {
        passwordStrength = PasswordStrengthValidator.evaluate(newPassword)
        if newPassword.isEmpty {
            passwordError = nil
            return
        }
        passwordError = passwordStrength.isStrong
            ? nil
            : languageService.text(.changePasswordWeakPassword)
        validateConfirmPasswordField()
    }

    func validateConfirmPasswordField() {
        if confirmPassword.isEmpty {
            confirmPasswordError = nil
            return
        }
        confirmPasswordError = newPassword == confirmPassword
            ? nil
            : languageService.text(.changePasswordPasswordsMismatch)
    }

    func verifyCurrentPassword() async {
        let trimmed = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            currentPasswordError = languageService.text(.changePasswordCurrentRequired)
            return
        }

        isVerifyingCurrentPassword = true
        currentPasswordError = nil
        defer { isVerifyingCurrentPassword = false }

        do {
            _ = try await loginUseCase.execute(email: accountEmail, password: trimmed)
            isCurrentPasswordVerified = true
        } catch let error as AuthError where error == .invalidCredentials {
            currentPasswordError = languageService.text(.changePasswordInvalidCurrent)
            isCurrentPasswordVerified = false
        } catch let error as AuthError {
            currentPasswordError = error.userMessage
            isCurrentPasswordVerified = false
        } catch {
            currentPasswordError = languageService.text(.changePasswordInvalidCurrent)
            isCurrentPasswordVerified = false
        }
    }

    func verifyEmailCodeStep() {
        guard otpCode.count == SplickOtpField.defaultLength else {
            otpError = languageService.text(.changePasswordOtpRequired)
            return
        }
        otpError = nil
        isEmailCodeVerified = true
    }

    func requestEmailCode() async {
        state = .loading
        otpError = nil
        do {
            try await requestEmailOtpUseCase.execute(email: accountEmail)
            otpInfoMessage = languageService.format(.changePasswordCodeSent, accountEmail)
            state = .idle
        } catch let error as AuthError {
            if error.shouldShowOnOtpStep {
                otpError = error.userMessage
                state = .idle
            } else {
                state = .failed(error.userMessage)
            }
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed(languageService.text(.changePasswordFailed))
        }
    }

    func changePassword() async {
        validatePasswordField()
        validateConfirmPasswordField()
        guard passwordStrength.isStrong, newPassword == confirmPassword else { return }

        switch method {
        case .currentPassword:
            guard isCurrentPasswordVerified else {
                currentPasswordError = languageService.text(.changePasswordCurrentRequired)
                return
            }
            currentPasswordError = nil
        case .emailCode:
            guard isEmailCodeVerified else {
                otpError = languageService.text(.changePasswordOtpRequired)
                return
            }
            otpError = nil
        }

        state = .loading
        do {
            let session = try await changePasswordUseCase.execute(
                currentPassword: method == .currentPassword ? currentPassword : nil,
                otpCode: method == .emailCode ? otpCode : nil,
                newPassword: newPassword
            )
            state = .loaded(session)
        } catch let error as AuthError {
            if error.shouldShowOnOtpStep {
                otpError = error.userMessage
                isEmailCodeVerified = false
                state = .idle
            } else if method == .currentPassword, error == .invalidCredentials {
                currentPasswordError = languageService.text(.changePasswordInvalidCurrent)
                isCurrentPasswordVerified = false
                state = .idle
            } else {
                state = .failed(error.userMessage)
            }
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed(languageService.text(.changePasswordFailed))
        }
    }

    private func resetVerificationState() {
        isCurrentPasswordVerified = false
        isEmailCodeVerified = false
        currentPasswordError = nil
        otpError = nil
        passwordError = nil
        confirmPasswordError = nil
        newPassword = ""
        confirmPassword = ""
        passwordStrength = .empty
    }
}
