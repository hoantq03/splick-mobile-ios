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
    let senderDisplayName: String?
    let body: String
    let clientMessageId: UUID
    let createdAt: Date
    let reactions: [ReactionResponseDTO]?
    let status: String?
    let attachments: [MessageAttachmentResponseDTO]?
    let replyPreview: MessageReplyPreviewResponseDTO?
}

struct MessageReplyPreviewResponseDTO: Decodable {
    let messageId: UUID
    let senderId: UUID
    let senderDisplayName: String?
    let body: String
    let hasImageAttachment: Bool
}

struct MessageAttachmentResponseDTO: Decodable {
    let mediaId: UUID?
    let url: String
    let thumbnailUrl: String?
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
    let groupId: UUID?
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
    let attachments: [MessageAttachmentRequestDTO]?
    let replyToMessageId: UUID?

    struct MessageAttachmentRequestDTO: Encodable {
        let mediaId: UUID?
        let url: String
        let thumbnailUrl: String?
    }
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
