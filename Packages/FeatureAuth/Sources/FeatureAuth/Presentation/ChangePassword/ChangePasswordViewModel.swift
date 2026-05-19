import Foundation
import SwiftUI
import Common
import DesignSystem
import SplickDomain

@MainActor
public final class ChangePasswordViewModel: ObservableObject {
    enum VerificationMethod: String, CaseIterable {
        case currentPassword = "Current password"
        case emailCode = "Email code"
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

    let accountEmail: String

    private let changePasswordUseCase: ChangePasswordUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol

    public init(
        accountEmail: String,
        changePasswordUseCase: ChangePasswordUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    ) {
        self.accountEmail = accountEmail
        self.changePasswordUseCase = changePasswordUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
    }

    func validatePasswordField() {
        passwordStrength = PasswordStrengthValidator.evaluate(newPassword)
        if newPassword.isEmpty {
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
        confirmPasswordError = newPassword == confirmPassword ? nil : "Passwords do not match"
    }

    func requestEmailCode() async {
        state = .loading
        do {
            try await requestEmailOtpUseCase.execute(email: accountEmail)
            otpInfoMessage = "Code sent to \(accountEmail). Check Mailpit at http://localhost:8025 (dev)."
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
            state = .failed("Could not send verification code.")
        }
    }

    func changePassword() async {
        validatePasswordField()
        validateConfirmPasswordField()
        guard passwordStrength.isStrong, newPassword == confirmPassword else { return }

        switch method {
        case .currentPassword:
            guard !currentPassword.isEmpty else {
                currentPasswordError = "Current password is required"
                return
            }
            currentPasswordError = nil
        case .emailCode:
            guard otpCode.count == 6 else {
                otpError = "Enter the 6-digit code"
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
                state = .idle
            } else {
                state = .failed(error.userMessage)
            }
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("Could not change password.")
        }
    }
}
