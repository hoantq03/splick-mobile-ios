import Foundation

public protocol MarkNotificationReadUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws
    func markAllRead() async throws
}

public final class MarkNotificationReadUseCase: MarkNotificationReadUseCaseProtocol, Sendable {
    private let repository: NotificationRepositoryProtocol

    public init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: UUID) async throws {
        try await repository.markAsRead(id: id)
    }

    public func markAllRead() async throws {
        try await repository.markAllAsRead()
    }
}
