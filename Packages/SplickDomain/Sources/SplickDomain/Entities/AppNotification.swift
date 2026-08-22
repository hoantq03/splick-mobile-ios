import Foundation

public struct AppNotification: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let type: NotificationType
    public let title: String
    public let body: String
    public let isRead: Bool
    public let referenceId: UUID?
    public let destination: NotificationDestination?
    public let actorUserId: UUID?
    public let actorAvatarURL: URL?
    public let createdAt: Date

    public init(
        id: UUID,
        type: NotificationType,
        title: String,
        body: String,
        isRead: Bool = false,
        referenceId: UUID? = nil,
        destination: NotificationDestination? = nil,
        actorUserId: UUID? = nil,
        actorAvatarURL: URL? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.isRead = isRead
        self.referenceId = referenceId
        self.destination = destination
        self.actorUserId = actorUserId
        self.actorAvatarURL = actorAvatarURL
        self.createdAt = createdAt
    }

    public var navigationTarget: NotificationNavigationTarget {
        if let postId = destination?.postDetailId {
            return .post(postId)
        }

        if let userId = destination?.userProfileId ?? (destination?.screen == .userProfile ? actorUserId : nil) {
            return .userProfile(userId)
        }

        switch destination?.screen {
        case .postDetail:
            if let referenceId {
                return .post(referenceId)
            }
            return .feed
        case .expenses:
            return .expenses
        case .friends:
            return .friends
        case .messages:
            if let conversationId = destination?.conversationId ?? referenceId {
                return .conversation(conversationId)
            }
            return .messages
        case .feed:
            return .feed
        case .inbox:
            return .inbox
        case .userProfile:
            break
        case .unknown, .none:
            break
        }

        switch type {
        case .feedTaggedInPost, .feedMentionedInPost, .feedMentionedInComment,
             .postCommented, .postReactionMilestone:
            if let referenceId {
                return .post(referenceId)
            }
            return .feed
        case .paymentEvidenceSubmitted, .paymentEvidenceApproved, .paymentEvidenceRejected,
             .expenseSplitBill, .expenseReminder, .expenseSettled,
             .dailyDebtReminder, .bulkSettlementPendingApproval, .bulkSettlementApproved,
             .bulkSettlementRejected:
            return .expenses
        case .streakReminderMidday, .streakReminderEvening:
            return .feed
        case .friendRequestAccepted:
            if let actorUserId {
                return .userProfile(actorUserId)
            }
            return .friends
        case .friendRequestSent, .groupInvite:
            return .friends
        case .directMessage, .groupMessage, .groupCreated, .groupMemberAdded,
             .groupMemberRemoved, .groupRenamed, .groupAdminTransferred:
            if let referenceId {
                return .conversation(referenceId)
            }
            return .messages
        case .system:
            return .none
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
            actorUserId: actorUserId,
            actorAvatarURL: actorAvatarURL,
            createdAt: createdAt
        )
    }
}

public enum NotificationType: String, Codable, Sendable {
    case postReactionMilestone = "POST_REACTION_MILESTONE"
    case feedTaggedInPost = "FEED_TAGGED_IN_POST"
    case feedMentionedInPost = "FEED_MENTIONED_IN_POST"
    case feedMentionedInComment = "FEED_MENTIONED_IN_COMMENT"
    case postCommented = "POST_COMMENTED"
    case paymentEvidenceSubmitted = "PAYMENT_EVIDENCE_SUBMITTED"
    case paymentEvidenceApproved = "PAYMENT_EVIDENCE_APPROVED"
    case paymentEvidenceRejected = "PAYMENT_EVIDENCE_REJECTED"
    case streakReminderMidday = "STREAK_REMINDER_MIDDAY"
    case streakReminderEvening = "STREAK_REMINDER_EVENING"
    case dailyDebtReminder = "DAILY_DEBT_REMINDER"
    case expenseSplitBill = "EXPENSE_SPLIT_BILL"
    case expenseReminder = "EXPENSE_REMINDER"
    case expenseSettled = "EXPENSE_SETTLED"
    case bulkSettlementPendingApproval = "BULK_SETTLEMENT_PENDING_APPROVAL"
    case bulkSettlementApproved = "BULK_SETTLEMENT_APPROVED"
    case bulkSettlementRejected = "BULK_SETTLEMENT_REJECTED"
    case friendRequestSent = "FRIEND_REQUEST_SENT"
    case friendRequestAccepted = "FRIEND_REQUEST_ACCEPTED"
    case groupInvite = "GROUP_INVITE"
    case directMessage = "DIRECT_MESSAGE"
    case groupMessage = "GROUP_MESSAGE"
    case groupCreated = "GROUP_CREATED"
    case groupMemberAdded = "GROUP_MEMBER_ADDED"
    case groupMemberRemoved = "GROUP_MEMBER_REMOVED"
    case groupRenamed = "GROUP_RENAMED"
    case groupAdminTransferred = "GROUP_ADMIN_TRANSFERRED"
    /// Fallback for unknown/legacy backend type strings.
    case system = "SYSTEM"

    public var isMessagingNotification: Bool {
        switch self {
        case .directMessage, .groupMessage, .groupCreated, .groupMemberAdded,
             .groupMemberRemoved, .groupRenamed, .groupAdminTransferred:
            return true
        default:
            return false
        }
    }

    /// Compact glyph for the avatar type chip — no nested-circle symbols.
    public var icon: String {
        switch self {
        case .feedTaggedInPost, .postCommented:
            return "photo.fill"
        case .postReactionMilestone:
            return "heart.fill"
        case .feedMentionedInPost, .feedMentionedInComment:
            return "at"
        case .paymentEvidenceSubmitted, .expenseSplitBill, .dailyDebtReminder,
             .bulkSettlementPendingApproval:
            return "banknote.fill"
        case .paymentEvidenceApproved, .expenseSettled, .bulkSettlementApproved:
            return "checkmark"
        case .paymentEvidenceRejected, .bulkSettlementRejected:
            return "xmark"
        case .expenseReminder:
            return "bell.fill"
        case .streakReminderMidday, .streakReminderEvening:
            return "flame.fill"
        case .friendRequestSent, .friendRequestAccepted:
            return "person.fill.badge.plus"
        case .groupInvite, .groupMessage, .groupCreated, .groupMemberAdded,
             .groupMemberRemoved, .groupRenamed, .groupAdminTransferred:
            return "person.3.fill"
        case .directMessage:
            return "bubble.left.fill"
        case .system:
            return "gearshape.fill"
        }
    }
}

public enum NotificationListCategory: String, Equatable, Hashable, Sendable, CaseIterable {
    case all
    case expenses
    case friends
    case posts

    public var queryValue: String? {
        switch self {
        case .all: return nil
        case .expenses: return "EXPENSES"
        case .friends: return "FRIENDS"
        case .posts: return "POSTS"
        }
    }
}
