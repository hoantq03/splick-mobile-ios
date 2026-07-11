import Foundation
import SplickDomain

enum MessagingMapper {

    static func toConversation(_ dto: ConversationResponseDTO) -> Conversation {
        let type = ConversationType(rawValue: dto.type ?? ConversationType.direct.rawValue) ?? .direct
        return Conversation(
            id: dto.id,
            type: type,
            unreadCount: dto.unreadCount,
            peer: dto.peer.map(toPeer),
            groupName: dto.groupName,
            groupAvatarUrl: dto.groupAvatarUrl,
            memberCount: dto.memberCount,
            lastMessage: dto.lastMessage.map(toMessage),
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    static func toPeer(_ dto: ConversationPeerResponseDTO) -> ConversationPeer {
        ConversationPeer(
            userId: dto.userId,
            username: dto.username,
            displayName: dto.displayName,
            avatarUrl: dto.avatarUrl
        )
    }

    static func toMessage(_ dto: MessageResponseDTO) -> ChatMessage {
        ChatMessage(
            id: dto.id,
            conversationId: dto.conversationId,
            senderId: dto.senderId,
            senderDisplayName: dto.senderDisplayName,
            body: dto.body,
            clientMessageId: dto.clientMessageId,
            createdAt: dto.createdAt,
            reactions: (dto.reactions ?? []).map(toReaction),
            deliveryStatus: mapDeliveryStatus(dto.status),
            imageAttachments: (dto.attachments ?? []).compactMap(toImageAttachment),
            replyPreview: dto.replyPreview.map(toReplyPreview)
        )
    }

    private static func toReplyPreview(_ dto: MessageReplyPreviewResponseDTO) -> MessageReplyPreview {
        MessageReplyPreview(
            messageId: dto.messageId,
            senderId: dto.senderId,
            senderDisplayName: dto.senderDisplayName,
            body: dto.body,
            hasImageAttachment: dto.hasImageAttachment
        )
    }

    private static func toImageAttachment(_ dto: MessageAttachmentResponseDTO) -> MessageImageAttachment? {
        guard let url = URL(string: dto.url) else { return nil }
        return MessageImageAttachment(
            mediaId: dto.mediaId,
            url: url,
            thumbnailURL: dto.thumbnailUrl.flatMap(URL.init(string:))
        )
    }

    private static func mapDeliveryStatus(_ raw: String?) -> MessageDeliveryStatus {
        switch raw?.lowercased() {
        case "delivered": return .delivered
        case "read": return .read
        case "failed": return .failed
        case "sending": return .sending
        default: return .sent
        }
    }

    static func toReaction(_ dto: ReactionResponseDTO) -> Reaction {
        Reaction(id: dto.id, emoji: dto.emoji, userId: dto.userId, createdAt: dto.createdAt)
    }

    static func toMessageSearchHit(_ dto: MessageSearchHitResponseDTO) -> MessageSearchHit? {
        guard let peerDTO = dto.peer else { return nil }
        return MessageSearchHit(
            messageId: dto.messageId,
            conversationId: dto.conversationId,
            body: dto.body,
            createdAt: dto.createdAt,
            peer: toPeer(peerDTO)
        )
    }
}
