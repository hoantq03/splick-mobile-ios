import Foundation
import SplickDomain
import FeatureNotification

public actor FakeNotificationRepository: NotificationRepositoryProtocol {
    private var notifications: [AppNotification] = []
    private var registeredTokens: Set<String> = []
    private var inboxLastSeenAt: Date?
    private let logger: StateLogger

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        notifications = [
            AppNotification(
                id: UUID(), type: .expenseSplitBill,
                title: "New Expense",
                body: "Linh added 'Korean BBQ dinner' — 450,000₫",
                isRead: false,
                createdAt: Date().addingTimeInterval(-1800)
            ),
            AppNotification(
                id: UUID(), type: .postReactionMilestone,
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
                id: UUID(), type: .friendRequestSent,
                title: "Friend Request",
                body: "Minh Thu wants to connect with you",
                isRead: false,
                referenceId: UUID(),
                createdAt: Date().addingTimeInterval(-172800)
            ),
            AppNotification(
                id: UUID(), type: .feedTaggedInPost,
                title: "Tagged in post",
                body: "Duc tagged you in a new moment",
                isRead: true,
                createdAt: Date().addingTimeInterval(-259200)
            ),
        ]

        logger.log("Seeded \(notifications.count) notifications")
    }

    public func fetchNotifications(page: Int, limit: Int, category: String?) async throws -> [AppNotification] {
        logger.log("Fetch notifications: page=\(page), limit=\(limit), category=\(category ?? "ALL")")
        try await Task.sleep(for: .milliseconds(300))

        let filtered: [AppNotification]
        switch category {
        case "EXPENSES":
            filtered = notifications.filter {
                switch $0.type {
                case .paymentEvidenceSubmitted, .paymentEvidenceApproved, .paymentEvidenceRejected,
                     .dailyDebtReminder, .expenseSplitBill, .expenseReminder, .expenseSettled,
                     .bulkSettlementPendingApproval, .bulkSettlementApproved, .bulkSettlementRejected:
                    return true
                default:
                    return false
                }
            }
        case "FRIENDS":
            filtered = notifications.filter {
                switch $0.type {
                case .friendRequestSent, .friendRequestAccepted, .friendNicknameChanged, .groupInvite, .groupDeleted:
                    return true
                default:
                    return false
                }
            }
        case "POSTS":
            filtered = notifications.filter {
                switch $0.type {
                case .feedTaggedInPost, .feedMentionedInPost, .feedMentionedInComment,
                     .postCommented, .postReactionMilestone, .streakReminderMidday, .streakReminderEvening:
                    return true
                default:
                    return false
                }
            }
        default:
            filtered = notifications
        }

        let start = page * limit
        guard start < filtered.count else { return [] }
        let end = min(start + limit, filtered.count)
        let result = Array(filtered[start..<end])

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

    public func markInboxSeen() async throws {
        inboxLastSeenAt = Date()
        logger.success("Notification inbox marked as seen")
    }

    public func unreadCount() async throws -> Int {
        let count = notifications.filter { !$0.isRead }.count
        logger.log("Unread count: \(count)")
        return count
    }

    public func fetchBadgeCounts() async throws -> TabBadgeCounts {
        let unread = notifications.filter { !$0.isRead }
        let inboxSource: [AppNotification]
        if let inboxLastSeenAt {
            inboxSource = notifications.filter { $0.createdAt > inboxLastSeenAt }
        } else {
            inboxSource = unread
        }
        var notificationsCount = 0
        var friends = 0
        var expenses = 0
        for item in inboxSource {
            switch item.type {
            case .friendRequestSent, .friendRequestAccepted, .friendNicknameChanged, .groupInvite, .groupDeleted:
                friends += 1
            case .expenseSplitBill, .expenseReminder, .expenseSettled,
                 .paymentEvidenceSubmitted, .paymentEvidenceApproved, .paymentEvidenceRejected,
                 .dailyDebtReminder, .bulkSettlementPendingApproval, .bulkSettlementApproved,
                 .bulkSettlementRejected:
                expenses += 1
            default:
                if !item.type.isMessagingNotification {
                    notificationsCount += 1
                }
            }
        }
        let messages = unread.filter(\.type.isMessagingNotification).count
        return TabBadgeCounts(
            notifications: notificationsCount,
            friends: friends,
            expenses: expenses,
            messages: messages
        )
    }

    public func registerDeviceToken(
        token: String,
        bundleId: String,
        environment: String
    ) async throws {
        registeredTokens.insert(token)
        logger.log(
            "Register device token: bundleId=\(bundleId), environment=\(environment), total=\(registeredTokens.count)"
        )
    }

    public func unregisterDeviceToken(token: String) async throws {
        registeredTokens.remove(token)
        logger.log("Unregister device token, remaining=\(registeredTokens.count)")
    }
}
