import Foundation
import Common

public protocol RevokeAllSessionsUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class RevokeAllSessionsUseCase: RevokeAllSessionsUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute() async throws {
        try await repository.revokeAllSessions()
        await repository.logout()
        await sessionManager.clearSession()
    }
}
