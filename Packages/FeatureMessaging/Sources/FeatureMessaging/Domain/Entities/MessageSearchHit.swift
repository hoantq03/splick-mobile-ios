import Foundation
import SplickDomain

public struct MessageSearchHit: Identifiable, Equatable, Sendable {
    public let messageId: UUID
    public let conversationId: UUID
    public let body: String
    public let createdAt: Date
    public let peer: ConversationPeer

    public var id: UUID { messageId }

    public init(
        messageId: UUID,
        conversationId: UUID,
        body: String,
        createdAt: Date,
        peer: ConversationPeer
    ) {
        self.messageId = messageId
        self.conversationId = conversationId
        self.body = body
        self.createdAt = createdAt
        self.peer = peer
    }
}

public enum MessagingSearchResult: Identifiable, Equatable, Sendable {
    case user(UserSummary)
    case message(MessageSearchHit)

    public var id: UUID {
        switch self {
        case .user(let user):
            return user.id
        case .message(let hit):
            return hit.messageId
        }
    }
}
