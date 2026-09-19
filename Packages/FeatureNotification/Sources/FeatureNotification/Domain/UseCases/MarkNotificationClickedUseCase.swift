import Foundation

public protocol MarkNotificationClickedUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws
}

public final class MarkNotificationClickedUseCase: MarkNotificationClickedUseCaseProtocol, Sendable {
    private let repository: NotificationRepositoryProtocol

    public init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: UUID) async throws {
        try await repository.markAsClicked(id: id)
    }
}
