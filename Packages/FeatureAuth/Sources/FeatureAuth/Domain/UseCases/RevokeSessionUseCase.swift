import Foundation

public protocol RevokeSessionUseCaseProtocol: Sendable {
    func execute(sessionId: UUID) async throws
}

public final class RevokeSessionUseCase: RevokeSessionUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(sessionId: UUID) async throws {
        try await repository.revokeSession(id: sessionId)
    }
}
