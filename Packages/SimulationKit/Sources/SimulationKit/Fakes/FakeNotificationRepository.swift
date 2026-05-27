import Foundation
import SplickDomain
import FeatureNotification

public actor FakeNotificationRepository: NotificationRepositoryProtocol {
    private var notifications: [AppNotification] = []
    private let logger: StateLogger

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        notifications = [
            AppNotification(
                id: UUID(), type: .expenseCreated,
                title: "New Expense",
                body: "Linh added 'Korean BBQ dinner' — 450,000₫",
                isRead: false,
                createdAt: Date().addingTimeInterval(-1800)
            ),
            AppNotification(
                id: UUID(), type: .reaction,
                title: "New Reaction",
                body: "Duc reacted ❤️ to your photo",
                isRead: false,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            AppNotification(
                id: UUID(), type: .expenseReminder,
                title: "Payment Reminder",
                body: "You owe Linh 150,000₫ for Korean BBQ",
                isRead: true,
                createdAt: Date().addingTimeInterval(-86400)
            ),
            AppNotification(
                id: UUID(), type: .friendRequest,
                title: "Friend Request",
                body: "Minh Thu wants to connect with you",
                isRead: true,
                createdAt: Date().addingTimeInterval(-172800)
            ),
            AppNotification(
                id: UUID(), type: .newPost,
                title: "New Photo",
                body: "Duc shared a new moment with you",
                isRead: true,
                createdAt: Date().addingTimeInterval(-259200)
            ),
        ]

        logger.log("Seeded \(notifications.count) notifications")
    }

    public func fetchNotifications(page: Int, limit: Int) async throws -> [AppNotification] {
        logger.log("Fetch notifications: page=\(page), limit=\(limit)")
        try await Task.sleep(for: .milliseconds(300))

        let start = page * limit
        guard start < notifications.count else { return [] }
        let end = min(start + limit, notifications.count)
        let result = Array(notifications[start..<end])

        logger.success("Loaded \(result.count) notifications (\(result.filter { !$0.isRead }.count) unread)")
        return result
    }

    public func markAsRead(id: UUID) async throws {
        logger.log("Mark read: \(id.uuidString.prefix(8))")
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index] = notifications[index].markingAsRead()
        }
        logger.success("Notification marked as read")
    }

    public func markAsClicked(id: UUID) async throws {
        logger.log("Mark clicked: \(id.uuidString.prefix(8))")
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index] = notifications[index].markingAsRead()
        }
        logger.success("Notification marked as clicked")
    }

    public func markAllAsRead() async throws {
        logger.log("Mark all as read")
        notifications = notifications.map { $0.markingAsRead() }
        logger.success("All \(notifications.count) notifications marked as read")
    }

    public func unreadCount() async throws -> Int {
        let count = notifications.filter { !$0.isRead }.count
        logger.log("Unread count: \(count)")
        return count
    }
}
