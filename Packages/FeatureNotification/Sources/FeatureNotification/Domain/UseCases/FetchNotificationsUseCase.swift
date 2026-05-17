import Foundation
import SplickDomain

public protocol FetchNotificationsUseCaseProtocol: Sendable {
    func execute(page: Int) async throws -> [AppNotification]
}

public final class FetchNotificationsUseCase: FetchNotificationsUseCaseProtocol, Sendable {
    private let repository: NotificationRepositoryProtocol
    private let pageSize: Int

    public init(repository: NotificationRepositoryProtocol, pageSize: Int = 20) {
        self.repository = repository
        self.pageSize = pageSize
    }

    public func execute(page: Int) async throws -> [AppNotification] {
        try await repository.fetchNotifications(page: page, limit: pageSize)
    }
}
