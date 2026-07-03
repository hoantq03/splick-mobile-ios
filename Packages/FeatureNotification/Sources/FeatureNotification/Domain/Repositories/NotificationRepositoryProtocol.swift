import Foundation
import SplickDomain

public protocol NotificationRepositoryProtocol: Sendable {
    func fetchNotifications(page: Int, limit: Int) async throws -> [AppNotification]
    func markAsRead(id: UUID) async throws
    func markAsClicked(id: UUID) async throws
    func markAllAsRead() async throws
    func unreadCount() async throws -> Int
    func fetchBadgeCounts() async throws -> TabBadgeCounts
    func registerDeviceToken(
        token: String,
        bundleId: String,
        environment: String
    ) async throws
    func unregisterDeviceToken(token: String) async throws
}
