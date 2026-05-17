import Foundation

public protocol LogoutUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class LogoutUseCase: LogoutUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute() async throws {
        try await repository.logout()
        await sessionManager.clearSession()
    }
}
