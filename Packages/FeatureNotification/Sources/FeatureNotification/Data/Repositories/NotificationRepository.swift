import Foundation
import Networking
import Common
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

    public func registerDeviceToken(
        token: String,
        bundleId: String,
        environment: String
    ) async throws {
        Log.info(
            "POST /v1/devices",
            category: .notification,
            metadata: [
                "bundleId": bundleId,
                "environment": environment,
                "tokenSuffix": token.suffix(8).description,
            ]
        )

        let request = RegisterPushDeviceRequestDTO(
            token: token,
            platform: "ios",
            bundleId: bundleId,
            environment: environment
        )
        try await apiClient.request(DeviceEndpoint.register(request))
    }

    public func unregisterDeviceToken(token: String) async throws {
        try await apiClient.request(DeviceEndpoint.unregister(token: token))
    }
}
