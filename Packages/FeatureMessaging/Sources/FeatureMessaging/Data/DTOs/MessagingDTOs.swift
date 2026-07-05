import Foundation

struct ConversationPeerResponseDTO: Decodable {
    let userId: UUID
    let username: String
    let displayName: String?
    let avatarUrl: String?
}

struct ConversationResponseDTO: Decodable {
    let id: UUID
    let type: String?
    let unreadCount: Int
    let peer: ConversationPeerResponseDTO?
    let groupName: String?
    let groupAvatarUrl: String?
    let memberCount: Int?
    let lastMessage: MessageResponseDTO?
    let createdAt: Date
    let updatedAt: Date
}

struct MessageResponseDTO: Decodable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let body: String
    let clientMessageId: UUID
    let createdAt: Date
    let reactions: [ReactionResponseDTO]?
}

struct ReactionResponseDTO: Decodable {
    let id: UUID
    let emoji: String
    let userId: UUID
    let createdAt: Date
}

struct CreateReactionRequestDTO: Encodable {
    let emoji: String
}

struct CreateConversationRequestDTO: Encodable {
    let friendUserId: UUID
}

struct CreateGroupConversationRequestDTO: Encodable {
    let name: String
    let avatarUrl: String?
    let memberUserIds: [UUID]
}

struct AddGroupMemberRequestDTO: Encodable {
    let memberUserId: UUID
}

struct RenameGroupRequestDTO: Encodable {
    let name: String
}

struct TransferGroupAdminRequestDTO: Encodable {
    let newAdminUserId: UUID
}

struct SendMessageRequestDTO: Encodable {
    let body: String
    let clientMessageId: UUID
}

struct MarkReadRequestDTO: Encodable {
    let upToMessageId: UUID
}

struct UnreadMessageCountDTO: Decodable {
    let unreadCount: Int
}

struct MessageSearchHitResponseDTO: Decodable {
    let messageId: UUID
    let conversationId: UUID
    let body: String
    let createdAt: Date
    let peer: ConversationPeerResponseDTO?
}
