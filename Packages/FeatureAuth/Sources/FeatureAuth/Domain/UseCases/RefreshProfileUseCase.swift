import Foundation
import SplickDomain

public protocol RefreshProfileUseCaseProtocol: Sendable {
    func execute() async throws -> User
}

public final class RefreshProfileUseCase: RefreshProfileUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute() async throws -> User {
        let user = try await repository.getCurrentUser()
        if let session = await sessionManager.currentSession() {
            let updated = AuthSession(user: user, token: session.token)
            await sessionManager.setSession(updated)
        }
        return user
    }
}
