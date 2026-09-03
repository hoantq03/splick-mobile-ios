import Foundation
import Common
import SplickDomain

public protocol ReactivateAccountUseCaseProtocol: Sendable {
    func execute(reactivationToken: String) async throws -> AuthSession
}

public final class ReactivateAccountUseCase: ReactivateAccountUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(reactivationToken: String) async throws -> AuthSession {
        let session = try await repository.reactivateAccount(reactivationToken: reactivationToken)
        guard session.user.status.allowsSignIn else {
            throw AuthError.accountLocked
        }
        await sessionManager.setSession(session)
        return session
    }
}
