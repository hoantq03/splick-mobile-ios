import Foundation
import FeatureMessaging
import FeatureNotification
import SplickDomain

struct StartupCachePayload: Codable, Sendable {
    let badgeCounts: CachedBadgeCounts
    let posts: [Post]
    let conversations: [CachedConversation]
    let emojis: [CustomEmoji]
    let currentStreak: Int
    let hasTodayPhoto: Bool
}

struct CachedBadgeCounts: Codable, Sendable {
    let notifications: Int
    let friends: Int
    let expenses: Int
    let messages: Int
}

struct CachedConversation: Codable, Sendable {
    let id: UUID
    let type: String
    let unreadCount: Int
    let peer: CachedConversationPeer?
    let groupName: String?
    let groupAvatarUrl: String?
    let memberCount: Int?
    let lastMessage: CachedMessage?
    let createdAt: Date
    let updatedAt: Date
}

struct CachedConversationPeer: Codable, Sendable {
    let userId: UUID
    let username: String
    let displayName: String?
    let avatarUrl: String?
}

struct CachedMessage: Codable, Sendable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let body: String
    let clientMessageId: UUID
    let createdAt: Date
}

enum StartupCacheMapper {
    static func toPayload(_ data: AppStartupData) -> StartupCachePayload {
        StartupCachePayload(
            badgeCounts: CachedBadgeCounts(
                notifications: data.badgeCounts.notifications,
                friends: data.badgeCounts.friends,
                expenses: data.badgeCounts.expenses,
                messages: data.badgeCounts.messages
            ),
            posts: data.posts,
            conversations: data.conversations.map(toCached),
            emojis: data.emojis,
            currentStreak: data.currentStreak,
            hasTodayPhoto: data.hasTodayPhoto
        )
    }

    static func fromPayload(_ payload: StartupCachePayload) -> AppStartupData {
        AppStartupData(
            badgeCounts: TabBadgeCounts(
                notifications: payload.badgeCounts.notifications,
                friends: payload.badgeCounts.friends,
                expenses: payload.badgeCounts.expenses,
                messages: payload.badgeCounts.messages
            ),
            posts: payload.posts,
            conversations: payload.conversations.map(fromCached),
            emojis: payload.emojis,
            currentStreak: payload.currentStreak,
            hasTodayPhoto: payload.hasTodayPhoto
        )
    }

    private static func toCached(_ conversation: Conversation) -> CachedConversation {
        CachedConversation(
            id: conversation.id,
            type: conversation.type.rawValue,
            unreadCount: conversation.unreadCount,
            peer: conversation.peer.map {
                CachedConversationPeer(
                    userId: $0.userId,
                    username: $0.username,
                    displayName: $0.displayName,
                    avatarUrl: $0.avatarUrl
                )
            },
            groupName: conversation.groupName,
            groupAvatarUrl: conversation.groupAvatarUrl,
            memberCount: conversation.memberCount,
            lastMessage: conversation.lastMessage.map {
                CachedMessage(
                    id: $0.id,
                    conversationId: $0.conversationId,
                    senderId: $0.senderId,
                    body: $0.body,
                    clientMessageId: $0.clientMessageId,
                    createdAt: $0.createdAt
                )
            },
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt
        )
    }

    private static func fromCached(_ cached: CachedConversation) -> Conversation {
        Conversation(
            id: cached.id,
            type: ConversationType(rawValue: cached.type) ?? .direct,
            unreadCount: cached.unreadCount,
            peer: cached.peer.map {
                ConversationPeer(
                    userId: $0.userId,
                    username: $0.username,
                    displayName: $0.displayName,
                    avatarUrl: $0.avatarUrl
                )
            },
            groupName: cached.groupName,
            groupAvatarUrl: cached.groupAvatarUrl,
            memberCount: cached.memberCount,
            lastMessage: cached.lastMessage.map {
                ChatMessage(
                    id: $0.id,
                    conversationId: $0.conversationId,
                    senderId: $0.senderId,
                    body: $0.body,
                    clientMessageId: $0.clientMessageId,
                    createdAt: $0.createdAt,
                    reactions: []
                )
            },
            createdAt: cached.createdAt,
            updatedAt: cached.updatedAt
        )
    }
}
