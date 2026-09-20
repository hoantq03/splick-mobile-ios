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
    @Published private(set) var sendCodeFailed = false
    @Published private(set) var otpResendSecondsRemaining = 0
    @Published private(set) var hasPasswordLogin = true
    @Published private(set) var isResolvingPasswordLogin = true

    let accountEmail: String

    private let changePasswordUseCase: ChangePasswordUseCaseProtocol
    private let verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol
    private let languageService: LanguageService
    private var resendCountdownTask: Task<Void, Never>?

    private static let otpResendCooldownSeconds = 60

    public init(
        accountEmail: String,
        changePasswordUseCase: ChangePasswordUseCaseProtocol,
        verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol,
        languageService: LanguageService
    ) {
        self.accountEmail = accountEmail
        self.changePasswordUseCase = changePasswordUseCase
        self.verifyPasswordChangeUseCase = verifyPasswordChangeUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.getConnectedAccountsUseCase = getConnectedAccountsUseCase
        self.languageService = languageService
    }

    func loadPasswordLoginState() async {
        isResolvingPasswordLogin = true
        defer { isResolvingPasswordLogin = false }
        do {
            let accounts = try await getConnectedAccountsUseCase.execute()
            applyHasPasswordLogin(accounts.emailPassword.isLinked)
        } catch {
            applyHasPasswordLogin(true)
        }
    }

    private func applyHasPasswordLogin(_ hasPassword: Bool) {
        hasPasswordLogin = hasPassword
        if !hasPassword {
            method = .emailCode
        }
    }

    func onMethodChanged() {
        resetVerificationState()
        stopOtpResendCountdown()
    }

    func onCurrentPasswordChanged() {
        currentPasswordError = nil
        guard isCurrentPasswordVerified, !isVerifyingCurrentPassword else { return }
        isCurrentPasswordVerified = false
    }

    func onOtpCodeChanged() {
        otpError = nil
        guard isEmailCodeVerified, !isVerifyingEmailCode else { return }
        isEmailCodeVerified = false
    }

    func validatePasswordField() {
        passwordStrength = PasswordStrengthValidator.evaluate(newPassword)
        if newPassword.isEmpty {
            passwordError = nil
            return
        }
        passwordError = nil
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
        let started = ContinuousClock.now

        do {
            try await verifyPasswordChangeUseCase.execute(
                currentPassword: trimmed,
                otpCode: nil
            )
            await holdMinimumLoading(from: started)
            isVerifyingCurrentPassword = false
            isCurrentPasswordVerified = true
        } catch {
            currentPasswordError = currentPasswordFailureMessage(error)
            isCurrentPasswordVerified = false
            await holdMinimumLoading(from: started)
            isVerifyingCurrentPassword = false
        }
    }

    func verifyEmailCodeStep() async {
        guard otpCode.count == SplickOtpField.defaultLength else {
            otpError = languageService.text(.changePasswordOtpRequired)
            return
        }

        isVerifyingEmailCode = true
        otpError = nil
        let started = ContinuousClock.now

        do {
            try await verifyPasswordChangeUseCase.execute(
                currentPassword: nil,
                otpCode: otpCode
            )
            await holdMinimumLoading(from: started)
            isVerifyingEmailCode = false
            isEmailCodeVerified = true
        } catch {
            otpError = otpFailureMessage(error)
            isEmailCodeVerified = false
            await holdMinimumLoading(from: started)
            isVerifyingEmailCode = false
        }
    }

    func requestEmailCode() async {
        guard otpResendSecondsRemaining == 0 else { return }

        isRequestingEmailCode = true
        sendCodeFailed = false
        otpError = nil
        let started = ContinuousClock.now

        do {
            try await requestEmailOtpUseCase.execute(email: accountEmail)
            await holdMinimumLoading(from: started)
            isRequestingEmailCode = false
            hasSentEmailCode = true
            otpInfoMessage = languageService.format(.changePasswordCodeSent, accountEmail)
            startOtpResendCountdown()
        } catch {
            applyEmailCodeRequestFailure(error)
            await holdMinimumLoading(from: started)
            isRequestingEmailCode = false
            sendCodeFailed = true
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
        let started = ContinuousClock.now
        do {
            let session = try await changePasswordUseCase.execute(
                currentPassword: method == .currentPassword ? currentPassword : nil,
                otpCode: method == .emailCode ? otpCode : nil,
                newPassword: newPassword
            )
            await holdMinimumLoading(from: started)
            await revealButtonResultThen {
                state = .loaded(session)
            }
        } catch let error as AuthError {
            await holdMinimumLoading(from: started)
            if error.shouldShowOnOtpStep {
                let message = otpFailureMessage(error)
                otpError = message
                state = .failed(message)
                try? await Task.sleep(nanoseconds: SplickButton.successHoldNanoseconds)
                isEmailCodeVerified = false
                state = .idle
            } else if method == .currentPassword, error == .invalidCredentials {
                currentPasswordError = languageService.text(.changePasswordInvalidCurrent)
                state = .failed(currentPasswordError ?? languageService.localizedMessage(for: error))
                try? await Task.sleep(nanoseconds: SplickButton.successHoldNanoseconds)
                isCurrentPasswordVerified = false
                state = .idle
            } else {
                state = .failed(languageService.localizedMessage(for: error))
            }
        } catch let error as NetworkError {
            await holdMinimumLoading(from: started)
            state = .failed(languageService.localizedMessage(for: error))
        } catch {
            await holdMinimumLoading(from: started)
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
        sendCodeFailed = false
        otpCode = ""
        newPassword = ""
        confirmPassword = ""
        passwordStrength = .empty
    }

    private func currentPasswordFailureMessage(_ error: Error) -> String {
        if let error = error as? AuthError, error == .invalidCredentials {
            return languageService.text(.changePasswordInvalidCurrent)
        }
        if let error = error as? NetworkError, case .unauthorized = error {
            return languageService.text(.changePasswordInvalidCurrent)
        }
        return languageService.localizedMessage(for: error)
    }

    private func otpFailureMessage(_ error: Error) -> String {
        if let error = error as? AuthError {
            switch error {
            case .otpRateLimited:
                return languageService.text(.errorAuthOtpRateLimited)
            default:
                return languageService.text(.errorAuthInvalidOtpDefault)
            }
        }
        if let error = error as? NetworkError, case .unauthorized = error {
            return languageService.text(.errorAuthInvalidOtpDefault)
        }
        return languageService.localizedMessage(for: error)
    }

    private func applyEmailCodeRequestFailure(_ error: Error) {
        if let error = error as? AuthError, error.shouldShowOnOtpStep {
            otpError = otpFailureMessage(error)
            return
        }
        state = .failed(languageService.localizedMessage(for: error))
    }

    private func holdMinimumLoading(from started: ContinuousClock.Instant) async {
        let minimum = Duration.nanoseconds(Int64(SplickButton.minimumLoadingNanoseconds))
        let elapsed = started.duration(to: .now)
        if elapsed < minimum {
            try? await Task.sleep(for: minimum - elapsed)
        }
    }

    private func revealButtonResultThen(_ work: () -> Void) async {
        state = .idle
        try? await Task.sleep(nanoseconds: SplickButton.successHoldNanoseconds)
        work()
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
