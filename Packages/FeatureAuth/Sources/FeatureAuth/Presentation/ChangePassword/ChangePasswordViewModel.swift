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
    @Published var isVerifyingEmailCode = false
    @Published private(set) var hasSentEmailCode = false
    @Published private(set) var isRequestingEmailCode = false
    @Published private(set) var otpResendSecondsRemaining = 0

    let accountEmail: String

    private let changePasswordUseCase: ChangePasswordUseCaseProtocol
    private let verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let languageService: LanguageService
    private var resendCountdownTask: Task<Void, Never>?

    private static let otpResendCooldownSeconds = 60

    public init(
        accountEmail: String,
        changePasswordUseCase: ChangePasswordUseCaseProtocol,
        verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        languageService: LanguageService
    ) {
        self.accountEmail = accountEmail
        self.changePasswordUseCase = changePasswordUseCase
        self.verifyPasswordChangeUseCase = verifyPasswordChangeUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.languageService = languageService
    }

    func onMethodChanged() {
        resetVerificationState()
        stopOtpResendCountdown()
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
            try await verifyPasswordChangeUseCase.execute(
                currentPassword: trimmed,
                otpCode: nil
            )
            isCurrentPasswordVerified = true
        } catch let error as AuthError where error == .invalidCredentials {
            currentPasswordError = languageService.text(.changePasswordInvalidCurrent)
            isCurrentPasswordVerified = false
        } catch let error as AuthError {
            currentPasswordError = error.userMessage
            isCurrentPasswordVerified = false
        } catch let error as NetworkError {
            if case .unauthorized = error {
                currentPasswordError = languageService.text(.changePasswordInvalidCurrent)
            } else {
                currentPasswordError = error.userMessage
            }
            isCurrentPasswordVerified = false
        } catch {
            currentPasswordError = languageService.text(.changePasswordInvalidCurrent)
            isCurrentPasswordVerified = false
        }
    }

    func verifyEmailCodeStep() async {
        guard otpCode.count == SplickOtpField.defaultLength else {
            otpError = languageService.text(.changePasswordOtpRequired)
            return
        }

        isVerifyingEmailCode = true
        otpError = nil
        defer { isVerifyingEmailCode = false }

        do {
            try await verifyPasswordChangeUseCase.execute(
                currentPassword: nil,
                otpCode: otpCode
            )
            isEmailCodeVerified = true
        } catch let error as AuthError {
            if error.shouldShowOnOtpStep {
                otpError = error.userMessage
            } else {
                otpError = languageService.text(.errorAuthInvalidOtpDefault)
            }
            isEmailCodeVerified = false
        } catch let error as NetworkError {
            if case .unauthorized = error {
                otpError = languageService.text(.errorAuthInvalidOtpDefault)
            } else {
                otpError = error.userMessage
            }
            isEmailCodeVerified = false
        } catch {
            otpError = languageService.text(.errorAuthInvalidOtpDefault)
            isEmailCodeVerified = false
        }
    }

    func requestEmailCode() async {
        guard otpResendSecondsRemaining == 0 else { return }

        isRequestingEmailCode = true
        otpError = nil
        defer { isRequestingEmailCode = false }

        do {
            try await requestEmailOtpUseCase.execute(email: accountEmail)
            hasSentEmailCode = true
            otpInfoMessage = languageService.format(.changePasswordCodeSent, accountEmail)
            startOtpResendCountdown()
        } catch let error as AuthError {
            if error.shouldShowOnOtpStep {
                otpError = error.userMessage
            } else {
                state = .failed(error.userMessage)
            }
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed(languageService.text(.changePasswordFailed))
        }
    }

    func resendEmailCode() async {
        await requestEmailCode()
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
        hasSentEmailCode = false
        currentPasswordError = nil
        otpError = nil
        passwordError = nil
        confirmPasswordError = nil
        otpInfoMessage = nil
        otpCode = ""
        newPassword = ""
        confirmPassword = ""
        passwordStrength = .empty
    }

    private func startOtpResendCountdown() {
        stopOtpResendCountdown()
        otpResendSecondsRemaining = Self.otpResendCooldownSeconds

        resendCountdownTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }

                if otpResendSecondsRemaining > 0 {
                    otpResendSecondsRemaining -= 1
                } else {
                    break
                }
            }
        }
    }

    private func stopOtpResendCountdown() {
        resendCountdownTask?.cancel()
        resendCountdownTask = nil
        otpResendSecondsRemaining = 0
    }
}
