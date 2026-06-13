import Foundation
import Networking
import SplickDomain

public final class NotificationRepository: NotificationRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchNotifications(page: Int, limit: Int) async throws -> [AppNotification] {
        let dtos: [NotificationResponseDTO] = try await apiClient.request(
            NotificationEndpoint.list(page: page, limit: limit)
        )
        return dtos.map(NotificationMapper.toNotification)
    }

    public func markAsRead(id: UUID) async throws {
        try await apiClient.request(NotificationEndpoint.markRead(id: id))
    }

    public func markAsClicked(id: UUID) async throws {
        try await apiClient.request(NotificationEndpoint.markClicked(id: id))
    }

    public func markAllAsRead() async throws {
        try await apiClient.request(NotificationEndpoint.markAllRead)
    }

    public func unreadCount() async throws -> Int {
        let dto: UnreadCountDTO = try await apiClient.request(NotificationEndpoint.unreadCount)
        return dto.count
    }

    public func fetchBadgeCounts() async throws -> TabBadgeCounts {
        let dto: BadgeCountsDTO = try await apiClient.request(NotificationEndpoint.badgeCounts)
        return TabBadgeCounts(
            notifications: dto.notifications,
            friends: dto.friends,
            expenses: dto.expenses,
            messages: dto.messages
        )
    }
}
