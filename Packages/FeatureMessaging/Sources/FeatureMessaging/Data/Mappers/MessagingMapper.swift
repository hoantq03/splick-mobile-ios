import Foundation
import SplickDomain

enum MessagingMapper {

    static func toConversation(_ dto: ConversationResponseDTO) -> Conversation {
        Conversation(
            id: dto.id,
            unreadCount: dto.unreadCount,
            peer: dto.peer.map(toPeer),
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
            body: dto.body,
            clientMessageId: dto.clientMessageId,
            createdAt: dto.createdAt,
            reactions: (dto.reactions ?? []).map(toReaction)
        )
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
