import Foundation
import Common

public protocol LogoutUseCaseProtocol: Sendable {
    func execute() async
}

public final class LogoutUseCase: LogoutUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute() async {
        await repository.logout()
        await sessionManager.clearSession()
        Log.info("Local session cleared", category: .auth)
    }
}
