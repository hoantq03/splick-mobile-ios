import Foundation

struct ConversationInboxSummaryResponseDTO: Decodable {
    let unreadConversationCount: Int
}

struct ConversationPeerResponseDTO: Decodable {
    let userId: UUID
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let online: Bool?
    let lastSeenAt: Date?

    private enum CodingKeys: String, CodingKey {
        case userId, username, displayName, avatarUrl, online, isOnline, lastSeenAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        online = try container.decodeIfPresent(Bool.self, forKey: .online)
            ?? container.decodeIfPresent(Bool.self, forKey: .isOnline)
        lastSeenAt = try? container.decode(Date.self, forKey: .lastSeenAt)
    }
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
    let notificationsEnabled: Bool?
    let notificationSound: String?
    let leftAt: Date?

    init(
        id: UUID,
        type: String? = nil,
        unreadCount: Int,
        peer: ConversationPeerResponseDTO? = nil,
        groupName: String? = nil,
        groupAvatarUrl: String? = nil,
        memberCount: Int? = nil,
        lastMessage: MessageResponseDTO? = nil,
        createdAt: Date,
        updatedAt: Date,
        notificationsEnabled: Bool? = true,
        notificationSound: String? = "default",
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
}

struct MessageResponseDTO: Decodable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let senderDisplayName: String?
    let body: String
    let clientMessageId: UUID
    let createdAt: Date
    let sequenceNo: Int64
    let editedAt: Date?
    let recalled: Bool
    let reactions: [ReactionResponseDTO]?
    let status: String?
    let attachments: [MessageAttachmentResponseDTO]?
    let replyPreview: MessageReplyPreviewResponseDTO?
    let type: String?

    init(
        id: UUID,
        conversationId: UUID,
        senderId: UUID,
        senderDisplayName: String? = nil,
        body: String,
        clientMessageId: UUID,
        createdAt: Date,
        sequenceNo: Int64 = 0,
        editedAt: Date? = nil,
        recalled: Bool = false,
        reactions: [ReactionResponseDTO]? = nil,
        status: String? = nil,
        attachments: [MessageAttachmentResponseDTO]? = nil,
        replyPreview: MessageReplyPreviewResponseDTO? = nil,
        type: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderDisplayName = senderDisplayName
        self.body = body
        self.clientMessageId = clientMessageId
        self.createdAt = createdAt
        self.sequenceNo = sequenceNo
        self.editedAt = editedAt
        self.recalled = recalled
        self.reactions = reactions
        self.status = status
        self.attachments = attachments
        self.replyPreview = replyPreview
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        conversationId = try container.decode(UUID.self, forKey: .conversationId)
        senderId = try container.decode(UUID.self, forKey: .senderId)
        senderDisplayName = try container.decodeIfPresent(String.self, forKey: .senderDisplayName)
        body = try container.decode(String.self, forKey: .body)
        clientMessageId = try container.decode(UUID.self, forKey: .clientMessageId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sequenceNo = try container.decodeIfPresent(Int64.self, forKey: .sequenceNo) ?? 0
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        recalled = try container.decodeIfPresent(Bool.self, forKey: .recalled) ?? false
        reactions = try container.decodeIfPresent([ReactionResponseDTO].self, forKey: .reactions)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        attachments = try container.decodeIfPresent([MessageAttachmentResponseDTO].self, forKey: .attachments)
        replyPreview = try container.decodeIfPresent(MessageReplyPreviewResponseDTO.self, forKey: .replyPreview)
        type = try container.decodeIfPresent(String.self, forKey: .type)
    }

    private enum CodingKeys: String, CodingKey {
        case id, conversationId, senderId, senderDisplayName, body, clientMessageId
        case createdAt, sequenceNo, editedAt, recalled, reactions, status, attachments, replyPreview, type
    }
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
    let shareChatHistory: Bool
}

struct RenameGroupRequestDTO: Encodable {
    let name: String
}

struct UpdateGroupAvatarRequestDTO: Encodable {
    let avatarUrl: String
}

struct UpdateConversationNotificationSettingsRequestDTO: Encodable {
    let notificationsEnabled: Bool
    let notificationSound: String
}

struct TransferGroupAdminRequestDTO: Encodable {
    let newAdminUserId: UUID
}

struct SendMessageRequestDTO: Encodable {
    struct MessageAttachmentRequestDTO: Encodable {
        let mediaId: UUID?
        let url: String
        let thumbnailUrl: String?
    }

    let body: String
    let clientMessageId: UUID
    let attachments: [MessageAttachmentRequestDTO]?
    let replyToMessageId: UUID?
}

struct EditMessageRequestDTO: Encodable {
    let body: String
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

struct WsTicketResponseDTO: Decodable {
    let ticket: String
}

struct GroupConversationMemberResponseDTO: Decodable {
    let id: UUID
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let role: String?
    let status: String?
}
