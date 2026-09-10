import Foundation
import Common
import SplickDomain

public protocol GoogleSignInUseCaseProtocol: Sendable {
    func execute(idToken: String) async throws -> AuthSession
}

public final class GoogleSignInUseCase: GoogleSignInUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(idToken: String) async throws -> AuthSession {
        let session = try await repository.signInWithGoogle(idToken: idToken)
        guard session.user.status.allowsSignIn else {
            throw AuthError.accountLocked
        }
        await sessionManager.setSession(session)
        return session
    }
}
