import Foundation

public struct AppNotification: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let type: NotificationType
    public let title: String
    public let body: String
    public let isRead: Bool
    public let referenceId: UUID?
    public let destination: NotificationDestination?
    public let createdAt: Date

    public init(
        id: UUID,
        type: NotificationType,
        title: String,
        body: String,
        isRead: Bool = false,
        referenceId: UUID? = nil,
        destination: NotificationDestination? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.isRead = isRead
        self.referenceId = referenceId
        self.destination = destination
        self.createdAt = createdAt
    }

    public var postNavigationId: UUID? {
        if let postId = destination?.postDetailId {
            return postId
        }
        guard let referenceId else { return nil }
        switch type {
        case .feedTaggedInPost, .feedMentioned, .postReacted, .reaction:
            return referenceId
        default:
            return nil
        }
    }

    public func markingAsRead() -> AppNotification {
        AppNotification(
            id: id,
            type: type,
            title: title,
            body: body,
            isRead: true,
            referenceId: referenceId,
            destination: destination,
            createdAt: createdAt
        )
    }
}

public enum NotificationType: String, Codable, Sendable {
    case newPost = "NEW_POST"
    case reaction = "REACTION"
    case postReacted = "POST_REACTED"
    case feedTaggedInPost = "FEED_TAGGED_IN_POST"
    case feedMentioned = "FEED_MENTIONED"
    case expenseCreated = "EXPENSE_CREATED"
    case expenseSplitBill = "EXPENSE_SPLIT_BILL"
    case expenseReminder = "EXPENSE_REMINDER"
    case expenseSettled = "EXPENSE_SETTLED"
    case friendRequest = "FRIEND_REQUEST"
    case friendRequestSent = "FRIEND_REQUEST_SENT"
    case groupInvite = "GROUP_INVITE"
    case system = "SYSTEM"

    public var icon: String {
        switch self {
        case .newPost, .feedTaggedInPost: return "photo.fill"
        case .reaction, .postReacted: return "heart.fill"
        case .feedMentioned: return "at"
        case .expenseCreated, .expenseSplitBill: return "dollarsign.circle.fill"
        case .expenseReminder: return "bell.fill"
        case .expenseSettled: return "checkmark.circle.fill"
        case .friendRequest, .friendRequestSent: return "person.badge.plus"
        case .groupInvite: return "person.3.fill"
        case .system: return "gear"
        }
    }
}
