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
    @Published public var password = ""
    @Published public var passwordError: String?
    @Published public var sheetError: String?
    @Published public private(set) var isVerified = false
    @Published public private(set) var isVerifying = false
    @Published public private(set) var isExecuting = false

    public let action: AccountClosureAction

    private let verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol
    private let deactivateAccountUseCase: DeactivateAccountUseCaseProtocol
    private let deleteAccountUseCase: DeleteAccountUseCaseProtocol
    private let languageService: LanguageService
    private let onCompleted: () -> Void

    public init(
        action: AccountClosureAction,
        verifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol,
        deactivateAccountUseCase: DeactivateAccountUseCaseProtocol,
        deleteAccountUseCase: DeleteAccountUseCaseProtocol,
        languageService: LanguageService,
        onCompleted: @escaping () -> Void
    ) {
        self.action = action
        self.verifyPasswordChangeUseCase = verifyPasswordChangeUseCase
        self.deactivateAccountUseCase = deactivateAccountUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.languageService = languageService
        self.onCompleted = onCompleted
    }

    public func reset() {
        password = ""
        passwordError = nil
        sheetError = nil
        isVerified = false
        isVerifying = false
        isExecuting = false
    }

    public func onPasswordChanged() {
        if isVerified {
            isVerified = false
        }
        passwordError = nil
        sheetError = nil
    }

    public func verifyPassword() async {
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

    public func executeAction() async -> Bool {
        guard isVerified else {
            passwordError = languageService.text(.accountClosureVerifyFirst)
            return false
        }

        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            passwordError = languageService.text(.changePasswordCurrentRequired)
            return false
        }

        isExecuting = true
        sheetError = nil
        defer { isExecuting = false }

        do {
            switch action {
            case .deactivate:
                try await deactivateAccountUseCase.execute(currentPassword: trimmed, otpCode: nil)
            case .delete:
                try await deleteAccountUseCase.execute(currentPassword: trimmed, otpCode: nil)
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
}
