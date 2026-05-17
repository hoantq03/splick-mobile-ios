import Foundation
import SplickDomain

public protocol RegisterUseCaseProtocol: Sendable {
    func execute(email: String, username: String, password: String) async throws -> AuthSession
}

public final class RegisterUseCase: RegisterUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(email: String, username: String, password: String) async throws -> AuthSession {
        let session = try await repository.register(
            email: email,
            username: username,
            password: password
        )
        await sessionManager.setSession(session)
        return session
    }
}
