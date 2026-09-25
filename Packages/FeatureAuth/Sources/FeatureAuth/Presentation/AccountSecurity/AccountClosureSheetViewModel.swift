import Foundation
import Common
import DesignSystem
import Localization

public enum AccountClosureAction: Identifiable, Equatable {
    case deactivate
    case delete

    public var id: Self { self }
}

@MainActor
public final class AccountClosureSheetViewModel: ObservableObject {
    public enum VerificationMethod: Hashable, CaseIterable {
        case password
        case emailCode
    }

    @Published public var method: VerificationMethod = .password
    @Published public var password = ""
    @Published public var otpCode = ""
    @Published public var passwordError: String?
    @Published public var otpError: String?
    @Published public var otpInfoMessage: String?
    @Published public var sheetError: String?
    @Published public private(set) var isVerified = false
    @Published public private(set) var isVerifying = false
    @Published public private(set) var isExecuting = false
    @Published public private(set) var hasSentEmailCode = false
    @Published public private(set) var isRequestingEmailCode = false
    @Published public private(set) var sendCodeFailed = false
    @Published public private(set) var otpResendSecondsRemaining = 0

    public let action: AccountClosureAction
    public let accountEmail: String
    public let canUseEmailVerification: Bool

    private let verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let deactivateAccountUseCase: DeactivateAccountUseCaseProtocol
    private let deleteAccountUseCase: DeleteAccountUseCaseProtocol
    private let languageService: LanguageService
    private let onCompleted: () -> Void
    private var resendCountdownTask: Task<Void, Never>?

    private static let otpResendCooldownSeconds = 60

    public init(
        action: AccountClosureAction,
        accountEmail: String,
        canUseEmailVerification: Bool,
        verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        deactivateAccountUseCase: DeactivateAccountUseCaseProtocol,
        deleteAccountUseCase: DeleteAccountUseCaseProtocol,
        languageService: LanguageService,
        onCompleted: @escaping () -> Void
    ) {
        self.action = action
        self.accountEmail = accountEmail
        self.canUseEmailVerification = canUseEmailVerification
        self.verifyPasswordChangeUseCase = verifyPasswordChangeUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.deactivateAccountUseCase = deactivateAccountUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.languageService = languageService
        self.onCompleted = onCompleted
        if !canUseEmailVerification {
            self.method = .password
        }
    }

    public func reset() {
        method = canUseEmailVerification ? .password : .password
        password = ""
        otpCode = ""
        passwordError = nil
        otpError = nil
        otpInfoMessage = nil
        sheetError = nil
        isVerified = false
        isVerifying = false
        isExecuting = false
        hasSentEmailCode = false
        isRequestingEmailCode = false
        sendCodeFailed = false
        otpResendSecondsRemaining = 0
        resendCountdownTask?.cancel()
        resendCountdownTask = nil
    }

    public func onMethodChanged() {
        password = ""
        otpCode = ""
        passwordError = nil
        otpError = nil
        otpInfoMessage = nil
        isVerified = false
        hasSentEmailCode = false
        sendCodeFailed = false
        stopOtpResendCountdown()
    }

    public func onPasswordChanged() {
        if isVerified {
            isVerified = false
        }
        passwordError = nil
        sheetError = nil
    }

    public func onOtpCodeChanged() {
        if isVerified {
            isVerified = false
        }
        otpError = nil
        sheetError = nil
    }

    public func verifyIdentity() async {
        switch method {
        case .password:
            await verifyPassword()
        case .emailCode:
            await verifyEmailCode()
        }
    }

    public func requestEmailCode() async {
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
            otpError = otpFailureMessage(error)
            await holdMinimumLoading(from: started)
            isRequestingEmailCode = false
            sendCodeFailed = true
        }
    }

    public func resendEmailCode() async {
        await requestEmailCode()
    }

    private func verifyPassword() async {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            passwordError = languageService.text(.changePasswordCurrentRequired)
            return
        }

        isVerifying = true
        passwordError = nil
        sheetError = nil
        let started = ContinuousClock.now

        do {
            try await verifyPasswordChangeUseCase.execute(currentPassword: trimmed, otpCode: nil)
            await holdMinimumLoading(from: started)
            isVerifying = false
            isVerified = true
        } catch {
            passwordError = currentPasswordFailureMessage(error)
            isVerified = false
            await holdMinimumLoading(from: started)
            isVerifying = false
        }
    }

    private func verifyEmailCode() async {
        guard otpCode.count == SplickOtpField.defaultLength else {
            otpError = languageService.text(.changePasswordOtpRequired)
            return
        }

        isVerifying = true
        otpError = nil
        sheetError = nil
        let started = ContinuousClock.now

        do {
            try await verifyPasswordChangeUseCase.execute(currentPassword: nil, otpCode: otpCode)
            await holdMinimumLoading(from: started)
            isVerifying = false
            isVerified = true
        } catch {
            otpError = otpFailureMessage(error)
            isVerified = false
            await holdMinimumLoading(from: started)
            isVerifying = false
        }
    }

    public func executeAction() async -> Bool {
        guard isVerified else {
            sheetError = languageService.text(.accountClosureVerifyFirst)
            return false
        }

        isExecuting = true
        sheetError = nil
        let started = ContinuousClock.now
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordCredential = method == .password ? trimmedPassword : nil
        let otpCredential = method == .emailCode ? otpCode : nil

        do {
            switch action {
            case .deactivate:
                try await deactivateAccountUseCase.execute(
                    currentPassword: passwordCredential,
                    otpCode: otpCredential
                )
            case .delete:
                try await deleteAccountUseCase.execute(
                    currentPassword: passwordCredential,
                    otpCode: otpCredential
                )
            }
            await holdMinimumLoading(from: started)
            isExecuting = false
            try? await Task.sleep(nanoseconds: SplickButton.successHoldNanoseconds)
            onCompleted()
            return true
        } catch {
            sheetError = executeFailureMessage(error)
            await holdMinimumLoading(from: started)
            isExecuting = false
            return false
        }
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

    private func executeFailureMessage(_ error: Error) -> String {
        if let error = error as? AuthError, error == .invalidCredentials {
            return method == .password
                ? languageService.text(.changePasswordInvalidCurrent)
                : languageService.text(.errorAuthInvalidOtpDefault)
        }
        if let error = error as? AuthError, error.shouldShowOnOtpStep {
            return otpFailureMessage(error)
        }
        if error is AuthError || error is NetworkError {
            return languageService.localizedMessage(for: error)
        }
        return action == .deactivate
            ? languageService.text(.accountClosureDeactivateFailed)
            : languageService.text(.accountClosureDeleteFailed)
    }

    private func holdMinimumLoading(from started: ContinuousClock.Instant) async {
        let minimum = Duration.nanoseconds(Int64(SplickButton.minimumLoadingNanoseconds))
        let elapsed = started.duration(to: .now)
        if elapsed < minimum {
            try? await Task.sleep(for: minimum - elapsed)
        }
    }

    private func startOtpResendCountdown() {
        stopOtpResendCountdown()
        otpResendSecondsRemaining = Self.otpResendCooldownSeconds
        resendCountdownTask = Task {
            while otpResendSecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                otpResendSecondsRemaining -= 1
            }
        }
    }

    private func stopOtpResendCountdown() {
        resendCountdownTask?.cancel()
        resendCountdownTask = nil
        otpResendSecondsRemaining = 0
    }
}
