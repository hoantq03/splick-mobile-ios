import Foundation

public struct WidgetDebtItem: Codable, Equatable, Sendable {
    public let userId: UUID
    public let displayName: String
    public let amount: String
    public let currency: String
    public let isOwed: Bool

    public init(
        userId: UUID,
        displayName: String,
        amount: String,
        currency: String,
        isOwed: Bool
    ) {
        self.userId = userId
        self.displayName = displayName
        self.amount = amount
        self.currency = currency
        self.isOwed = isOwed
    }
}

public struct WidgetExpenseSummarySnapshot: Codable, Equatable, Sendable {
    public let netAmount: String
    public let currency: String
    public let totalOwing: String
    public let totalOwed: String
    public let owingPeopleCount: Int
    public let owedPeopleCount: Int
    public let topDebts: [WidgetDebtItem]
    public let updatedAt: Date

    public init(
        netAmount: String,
        currency: String,
        totalOwing: String,
        totalOwed: String,
        owingPeopleCount: Int,
        owedPeopleCount: Int,
        topDebts: [WidgetDebtItem],
        updatedAt: Date = .now
    ) {
        self.netAmount = netAmount
        self.currency = currency
        self.totalOwing = totalOwing
        self.totalOwed = totalOwed
        self.owingPeopleCount = owingPeopleCount
        self.owedPeopleCount = owedPeopleCount
        self.topDebts = topDebts
        self.updatedAt = updatedAt
    }
}

public struct WidgetConversationPreview: Codable, Equatable, Sendable {
    public let id: UUID
    public let displayTitle: String
    public let previewText: String
    public let unreadCount: Int
    public let avatarURL: String?
    public let updatedAt: Date

    public init(
        id: UUID,
        displayTitle: String,
        previewText: String,
        unreadCount: Int,
        avatarURL: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.displayTitle = displayTitle
        self.previewText = previewText
        self.unreadCount = unreadCount
        self.avatarURL = avatarURL
        self.updatedAt = updatedAt
    }
}

public struct WidgetMessagingInboxSnapshot: Codable, Equatable, Sendable {
    public let totalUnreadCount: Int
    public let conversations: [WidgetConversationPreview]
    public let updatedAt: Date

    public init(
        totalUnreadCount: Int,
        conversations: [WidgetConversationPreview],
        updatedAt: Date = .now
    ) {
        self.totalUnreadCount = totalUnreadCount
        self.conversations = conversations
        self.updatedAt = updatedAt
    }
}

public struct WidgetLatestFriendPhotoSnapshot: Codable, Equatable, Sendable {
    public let postId: UUID
    public let authorName: String
    public let authorUsername: String
    public let reactionCount: Int
    public let createdAt: Date
    public let cachedImageFilename: String?
    public let remoteImageURL: String?

    public init(
        postId: UUID,
        authorName: String,
        authorUsername: String,
        reactionCount: Int,
        createdAt: Date,
        cachedImageFilename: String?,
        remoteImageURL: String?
    ) {
        self.postId = postId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.reactionCount = reactionCount
        self.createdAt = createdAt
        self.cachedImageFilename = cachedImageFilename
        self.remoteImageURL = remoteImageURL
    }
}

public struct WidgetStreakSnapshot: Codable, Equatable, Sendable {
    public let currentStreak: Int
    public let hasTodayPhoto: Bool
    public let updatedAt: Date

    public init(currentStreak: Int, hasTodayPhoto: Bool, updatedAt: Date = .now) {
        self.currentStreak = currentStreak
        self.hasTodayPhoto = hasTodayPhoto
        self.updatedAt = updatedAt
    }
}

public struct WidgetFriendRequestPreview: Codable, Equatable, Sendable {
    public let id: UUID
    public let requesterName: String
    public let requesterUsername: String
    public let avatarURL: String?
    public let createdAt: Date

    public init(
        id: UUID,
        requesterName: String,
        requesterUsername: String,
        avatarURL: String?,
        createdAt: Date
    ) {
        self.id = id
        self.requesterName = requesterName
        self.requesterUsername = requesterUsername
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
}

public struct WidgetFriendRequestsSnapshot: Codable, Equatable, Sendable {
    public let pendingCount: Int
    public let requests: [WidgetFriendRequestPreview]
    public let updatedAt: Date

    public init(
        pendingCount: Int,
        requests: [WidgetFriendRequestPreview],
        updatedAt: Date = .now
    ) {
        self.pendingCount = pendingCount
        self.requests = requests
        self.updatedAt = updatedAt
    }
}

public struct WidgetGroupOption: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let memberCount: Int

    public init(id: UUID, name: String, memberCount: Int) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
    }
}

public struct WidgetGroupsSnapshot: Codable, Equatable, Sendable {
    public let groups: [WidgetGroupOption]
    public let updatedAt: Date

    public init(groups: [WidgetGroupOption], updatedAt: Date = .now) {
        self.groups = groups
        self.updatedAt = updatedAt
    }
}

public struct WidgetGroupMemberBalance: Codable, Equatable, Sendable {
    public let userId: UUID
    public let displayName: String
    public let amount: String
    public let isOwed: Bool

    public init(userId: UUID, displayName: String, amount: String, isOwed: Bool) {
        self.userId = userId
        self.displayName = displayName
        self.amount = amount
        self.isOwed = isOwed
    }
}

public struct WidgetGroupExpenseSnapshot: Codable, Equatable, Sendable {
    public let groupId: UUID
    public let groupName: String
    public let totalAmount: String
    public let settledPercentage: Int
    public let currency: String
    public let memberBalances: [WidgetGroupMemberBalance]
    public let updatedAt: Date

    public init(
        groupId: UUID,
        groupName: String,
        totalAmount: String,
        settledPercentage: Int,
        currency: String,
        memberBalances: [WidgetGroupMemberBalance],
        updatedAt: Date = .now
    ) {
        self.groupId = groupId
        self.groupName = groupName
        self.totalAmount = totalAmount
        self.settledPercentage = settledPercentage
        self.currency = currency
        self.memberBalances = memberBalances
        self.updatedAt = updatedAt
    }
}
