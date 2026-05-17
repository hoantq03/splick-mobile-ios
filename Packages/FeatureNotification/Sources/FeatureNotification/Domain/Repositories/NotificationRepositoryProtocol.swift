import Foundation
import SplickDomain

public protocol NotificationRepositoryProtocol: Sendable {
    func fetchNotifications(page: Int, limit: Int) async throws -> [AppNotification]
    func markAsRead(id: UUID) async throws
    func markAllAsRead() async throws
    func unreadCount() async throws -> Int
}
