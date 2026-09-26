import Foundation

public protocol MarkInboxSeenUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class MarkInboxSeenUseCase: MarkInboxSeenUseCaseProtocol, Sendable {
    private let repository: NotificationRepositoryProtocol

    public init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.markInboxSeen()
    }
}
