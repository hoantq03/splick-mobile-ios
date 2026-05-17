import Foundation
import SplickDomain

public protocol LoginUseCaseProtocol: Sendable {
    func execute(email: String, password: String) async throws -> AuthSession
}

public final class LoginUseCase: LoginUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(email: String, password: String) async throws -> AuthSession {
        let session = try await repository.login(email: email, password: password)
        await sessionManager.setSession(session)
        return session
    }
}
