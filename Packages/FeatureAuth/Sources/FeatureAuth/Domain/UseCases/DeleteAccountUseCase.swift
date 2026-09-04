import Foundation
import Common

public protocol DeleteAccountUseCaseProtocol: Sendable {
    func execute(currentPassword: String?, otpCode: String?) async throws
}

public final class DeleteAccountUseCase: DeleteAccountUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(currentPassword: String?, otpCode: String?) async throws {
        try await repository.deleteAccount(currentPassword: currentPassword, otpCode: otpCode)
        await repository.logout()
        await sessionManager.clearSession()
    }
}
