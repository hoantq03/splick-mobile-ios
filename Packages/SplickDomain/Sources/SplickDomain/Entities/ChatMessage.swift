import Foundation
import SplickDomain

public struct ChatMessage: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let conversationId: UUID
    public let senderId: UUID
    public let body: String
    public let clientMessageId: UUID
    public let createdAt: Date
    public let reactions: [Reaction]
    public let deliveryStatus: MessageDeliveryStatus

    public init(
        id: UUID,
        conversationId: UUID,
        senderId: UUID,
        body: String,
        clientMessageId: UUID,
        createdAt: Date,
        reactions: [Reaction] = [],
        deliveryStatus: MessageDeliveryStatus = .sent
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.body = body
        self.clientMessageId = clientMessageId
        self.createdAt = createdAt
        self.reactions = reactions
        self.deliveryStatus = deliveryStatus
    }

    public func updating(reactions: [Reaction]) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            body: body,
            clientMessageId: clientMessageId,
            createdAt: createdAt,
            reactions: reactions,
            deliveryStatus: deliveryStatus
        )
    }

    public func updating(deliveryStatus: MessageDeliveryStatus) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            body: body,
            clientMessageId: clientMessageId,
            createdAt: createdAt,
            reactions: reactions,
            deliveryStatus: deliveryStatus
        )
    }

    /// Aggregated emoji counts for compact display, e.g. ❤️×3 😂×1
    public func reactionCounts() -> [(emoji: String, count: Int)] {
        let grouped = Dictionary(grouping: reactions, by: \.emoji)
        return grouped
            .map { (emoji: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.emoji < rhs.emoji
            }
    }

    /// Pills ordered from the bubble inner edge outward (first-added sits next to the bubble).
    public func reactionCountsInsideOut(isOutgoing: Bool) -> [(emoji: String, count: Int)] {
        var emojiOrder: [String] = []
        for reaction in reactions where !emojiOrder.contains(reaction.emoji) {
            emojiOrder.append(reaction.emoji)
        }

        let grouped = Dictionary(grouping: reactions, by: \.emoji)
        let ordered = emojiOrder.map { emoji in
            (emoji: emoji, count: grouped[emoji]?.count ?? 0)
        }

        // Outgoing: grow left → right from inner (leading) edge.
        // Incoming: grow right → left from inner (trailing) edge.
        return isOutgoing ? ordered : ordered.reversed()
    }

    /// Last emoji the given user reacted with on this message (most recent by append order).
    public func lastReactionEmoji(for userId: UUID) -> String? {
        reactions.last(where: { $0.userId == userId })?.emoji
    }
}
