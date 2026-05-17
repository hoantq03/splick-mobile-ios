import Foundation

public struct AppNotification: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let type: NotificationType
    public let title: String
    public let body: String
    public let isRead: Bool
    public let referenceId: UUID?
    public let createdAt: Date

    public init(
        id: UUID,
        type: NotificationType,
        title: String,
        body: String,
        isRead: Bool = false,
        referenceId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.isRead = isRead
        self.referenceId = referenceId
        self.createdAt = createdAt
    }
}

public enum NotificationType: String, Codable, Sendable {
    case newPost = "NEW_POST"
    case reaction = "REACTION"
    case expenseCreated = "EXPENSE_CREATED"
    case expenseReminder = "EXPENSE_REMINDER"
    case expenseSettled = "EXPENSE_SETTLED"
    case friendRequest = "FRIEND_REQUEST"
    case groupInvite = "GROUP_INVITE"
    case system = "SYSTEM"

    public var icon: String {
        switch self {
        case .newPost: return "photo.fill"
        case .reaction: return "heart.fill"
        case .expenseCreated: return "dollarsign.circle.fill"
        case .expenseReminder: return "bell.fill"
        case .expenseSettled: return "checkmark.circle.fill"
        case .friendRequest: return "person.badge.plus"
        case .groupInvite: return "person.3.fill"
        case .system: return "gear"
        }
    }
}
