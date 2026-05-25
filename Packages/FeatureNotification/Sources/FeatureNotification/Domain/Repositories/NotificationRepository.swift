import Foundation

public protocol NotificationRepository {
    func getNotifications(page: Int, limit: Int) async throws -> [NotificationItem]
    func markAsClicked(id: UUID) async throws
}
