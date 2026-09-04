import Foundation
import SplickDomain

public protocol ListSessionsUseCaseProtocol: Sendable {
    func execute() async throws -> [UserSession]
}

public final class ListSessionsUseCase: ListSessionsUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [UserSession] {
        try await repository.listSessions()
    }
}
