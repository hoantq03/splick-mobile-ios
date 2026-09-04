import Foundation

struct StartupDataResponseDTO: Decodable {
    let badgeCounts: StartupBadgeCountsDTO
    let currentStreak: Int
    let hasTodayPhoto: Bool
    let feedFirstPage: [PostDTO]
    let conversations: [StartupConversationDTO]
    let customEmojis: [StartupCustomEmojiDTO]
}

struct StartupBadgeCountsDTO: Decodable {
    let notifications: Int
    let friends: Int
    let expenses: Int
    let messages: Int
    let inbox: Int?
}

struct StartupConversationDTO: Decodable {
    let id: UUID
    let type: String?
    let unreadCount: Int
    let peer: StartupConversationPeerDTO?
    let groupName: String?
    let groupAvatarUrl: String?
    let memberCount: Int?
    let lastMessage: StartupMessageDTO?
    let createdAt: Date
    let updatedAt: Date
}

struct StartupConversationPeerDTO: Decodable {
    let userId: UUID
    let username: String
    let displayName: String?
    let avatarUrl: String?
}

struct StartupMessageDTO: Decodable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let body: String
    let clientMessageId: UUID?
    let createdAt: Date
    let reactions: [StartupReactionDTO]?
}

struct StartupReactionDTO: Decodable {
    let id: UUID
    let emoji: String
    let userId: UUID
    let createdAt: Date
}

struct StartupCustomEmojiDTO: Decodable {
    let id: UUID
    let ownerId: UUID?
    let shortcode: String
    let mediaUrl: String
    let createdAt: Date
}
