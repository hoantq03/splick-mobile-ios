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
        otpError = nil
        defer { isRequestingEmailCode = false }

        do {
            try await requestEmailOtpUseCase.execute(email: accountEmail)
            hasSentEmailCode = true
            otpInfoMessage = languageService.format(.changePasswordCodeSent, accountEmail)
            startOtpResendCountdown()
        } catch let error as AuthError {
            otpError = error.userMessage
        } catch let error as NetworkError {
            otpError = error.userMessage
        } catch {
            otpError = languageService.text(.connectedAccountsSendCodeFailed)
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
        defer { isVerifying = false }

        do {
            try await verifyPasswordChangeUseCase.execute(currentPassword: trimmed, otpCode: nil)
            isVerified = true
        } catch let error as AuthError where error == .invalidCredentials {
            passwordError = languageService.text(.changePasswordInvalidCurrent)
            isVerified = false
        } catch let error as AuthError {
            passwordError = error.userMessage
            isVerified = false
        } catch let error as NetworkError {
            if case .unauthorized = error {
                passwordError = languageService.text(.changePasswordInvalidCurrent)
            } else {
                passwordError = error.userMessage
            }
            isVerified = false
        } catch {
            passwordError = languageService.text(.changePasswordInvalidCurrent)
            isVerified = false
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
        defer { isVerifying = false }

        do {
            try await verifyPasswordChangeUseCase.execute(currentPassword: nil, otpCode: otpCode)
            isVerified = true
        } catch let error as AuthError {
            otpError = error.shouldShowOnOtpStep
                ? error.userMessage
                : languageService.text(.errorAuthInvalidOtpDefault)
            isVerified = false
        } catch let error as NetworkError {
            otpError = languageService.text(.errorAuthInvalidOtpDefault)
            isVerified = false
        } catch {
            otpError = languageService.text(.errorAuthInvalidOtpDefault)
            isVerified = false
        }
    }

    public func executeAction() async -> Bool {
        guard isVerified else {
            sheetError = languageService.text(.accountClosureVerifyFirst)
            return false
        }

        isExecuting = true
        sheetError = nil
        defer { isExecuting = false }

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
            onCompleted()
            return true
        } catch let error as AuthError {
            sheetError = error.userMessage
            return false
        } catch let error as NetworkError {
            sheetError = error.userMessage
            return false
        } catch {
            sheetError = action == .deactivate
                ? languageService.text(.accountClosureDeactivateFailed)
                : languageService.text(.accountClosureDeleteFailed)
            return false
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
