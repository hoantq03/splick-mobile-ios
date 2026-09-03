import Foundation
import SplickDomain

public enum ConversationType: String, Equatable, Hashable, Sendable {
    case direct = "DIRECT"
    case group = "GROUP"
}

public struct ConversationPeer: Equatable, Hashable, Sendable {
    public let userId: UUID
    public let username: String
    public let displayName: String?
    public let avatarUrl: String?
    public let isOnline: Bool?
    public let lastSeenAt: Date?

    public var displayTitle: String {
        displayName?.isEmpty == false ? displayName! : username
    }

    public init(
        userId: UUID,
        username: String,
        displayName: String?,
        avatarUrl: String?,
        isOnline: Bool? = nil,
        lastSeenAt: Date? = nil
    ) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
    }

    public func updatingPresence(isOnline: Bool?, lastSeenAt: Date?) -> ConversationPeer {
        ConversationPeer(
            userId: userId,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            isOnline: isOnline ?? self.isOnline,
            lastSeenAt: lastSeenAt ?? self.lastSeenAt
        )
    }
}

public struct Conversation: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let type: ConversationType
    public let unreadCount: Int
    public let peer: ConversationPeer?
    public let groupName: String?
    public let groupAvatarUrl: String?
    public let memberCount: Int?
    public let lastMessage: ChatMessage?
    public let createdAt: Date
    public let updatedAt: Date
    public let notificationsEnabled: Bool
    public let notificationSound: String
    public let leftAt: Date?

    public var isRemovedFromGroup: Bool { leftAt != nil }
    
    public var displayTitle: String {
        if type == .group {
            return groupName ?? "Group"
        }
        return peer?.displayTitle ?? String(id.uuidString.prefix(8))
    }
    
    public var isGroup: Bool {
        type == .group
    }
    
    public init(
        id: UUID,
        type: ConversationType = .direct,
        unreadCount: Int,
        peer: ConversationPeer?,
        groupName: String? = nil,
        groupAvatarUrl: String? = nil,
        memberCount: Int? = nil,
        lastMessage: ChatMessage?,
        createdAt: Date,
        updatedAt: Date,
        notificationsEnabled: Bool = true,
        notificationSound: String = ConversationNotificationSound.default.rawValue,
        leftAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.unreadCount = unreadCount
        self.peer = peer
        self.groupName = groupName
        self.groupAvatarUrl = groupAvatarUrl
        self.memberCount = memberCount
        self.lastMessage = lastMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notificationsEnabled = notificationsEnabled
        self.notificationSound = notificationSound
        self.leftAt = leftAt
    }
    
    public func updating(unreadCount: Int) -> Conversation {
        Conversation(
            id: id,
            type: type,
            unreadCount: max(0, unreadCount),
            peer: peer,
            groupName: groupName,
            groupAvatarUrl: groupAvatarUrl,
            memberCount: memberCount,
            lastMessage: lastMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound,
            leftAt: leftAt
        )
    }
    
    public func updating(groupName: String) -> Conversation {
        Conversation(
            id: id,
            type: type,
            unreadCount: unreadCount,
            peer: peer,
            groupName: groupName,
            groupAvatarUrl: groupAvatarUrl,
            memberCount: memberCount,
            lastMessage: lastMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound,
            leftAt: leftAt
        )
    }
    
    public func updating(groupAvatarUrl: String?) -> Conversation {
        Conversation(
            id: id,
            type: type,
            unreadCount: unreadCount,
            peer: peer,
            groupName: groupName,
            groupAvatarUrl: groupAvatarUrl,
            memberCount: memberCount,
            lastMessage: lastMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound,
            leftAt: leftAt
        )
    }
    
    /// Local inbox patch from a live message (WebSocket) — keeps list snappy without a full REST reload.
    public func updating(
        lastMessage: ChatMessage,
        unreadCount: Int,
        updatedAt: Date
    ) -> Conversation {
        Conversation(
            id: id,
            type: type,
            unreadCount: max(0, unreadCount),
            peer: peer,
            groupName: groupName,
            groupAvatarUrl: groupAvatarUrl,
            memberCount: memberCount,
            lastMessage: lastMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound,
            leftAt: leftAt
        )
    }
    
    public func updatingNotificationSettings(enabled: Bool, sound: String) -> Conversation {
        Conversation(
            id: id,
            type: type,
            unreadCount: unreadCount,
            peer: peer,
            groupName: groupName,
            groupAvatarUrl: groupAvatarUrl,
            memberCount: memberCount,
            lastMessage: lastMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            notificationsEnabled: enabled,
            notificationSound: sound,
            leftAt: leftAt
        )
    }

    public func updating(peer: ConversationPeer?) -> Conversation {
        Conversation(
            id: id,
            type: type,
            unreadCount: unreadCount,
            peer: peer,
            groupName: groupName,
            groupAvatarUrl: groupAvatarUrl,
            memberCount: memberCount,
            lastMessage: lastMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound,
            leftAt: leftAt
        )
    }

    public func updating(leftAt: Date?) -> Conversation {
        Conversation(
            id: id,
            type: type,
            unreadCount: unreadCount,
            peer: peer,
            groupName: groupName,
            groupAvatarUrl: groupAvatarUrl,
            memberCount: memberCount,
            lastMessage: lastMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound,
            leftAt: leftAt
        )
    }
}
