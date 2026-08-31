import Foundation

public enum ChatMessageType: String, Equatable, Hashable, Sendable, Codable {
    case user = "USER"
    case groupRenamed = "GROUP_RENAMED"
    case groupMemberRemoved = "GROUP_MEMBER_REMOVED"
    case groupMemberLeft = "GROUP_MEMBER_LEFT"
}

public struct ChatMessage: Identifiable, Equatable, Hashable, Sendable, Codable {
    public static let editRecallWindow: TimeInterval = 5 * 60

    public let id: UUID
    public let conversationId: UUID
    public let senderId: UUID
    public let senderDisplayName: String?
    public let body: String
    public let clientMessageId: UUID
    public let createdAt: Date
    /// Monotonic per-conversation sequence from the server. `0` means unknown / legacy.
    public let sequenceNo: Int64
    public let reactions: [Reaction]
    public let deliveryStatus: MessageDeliveryStatus
    public let imageAttachments: [MessageImageAttachment]
    public let replyPreview: MessageReplyPreview?
    public let type: ChatMessageType?
    public let editedAt: Date?
    public let recalled: Bool

    public var isSystemNotice: Bool {
        switch type {
        case .groupRenamed, .groupMemberRemoved, .groupMemberLeft:
            return true
        case .user, .none:
            return false
        }
    }

    public var isEdited: Bool { editedAt != nil && !recalled }

    public init(
        id: UUID,
        conversationId: UUID,
        senderId: UUID,
        senderDisplayName: String? = nil,
        body: String,
        clientMessageId: UUID,
        createdAt: Date,
        sequenceNo: Int64 = 0,
        reactions: [Reaction] = [],
        deliveryStatus: MessageDeliveryStatus = .sent,
        imageAttachments: [MessageImageAttachment] = [],
        replyPreview: MessageReplyPreview? = nil,
        type: ChatMessageType? = nil,
        editedAt: Date? = nil,
        recalled: Bool = false
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderDisplayName = senderDisplayName
        self.body = body
        self.clientMessageId = clientMessageId
        self.createdAt = createdAt
        self.sequenceNo = sequenceNo
        self.reactions = reactions
        self.deliveryStatus = deliveryStatus
        self.imageAttachments = imageAttachments
        self.replyPreview = replyPreview
        self.type = type
        self.editedAt = editedAt
        self.recalled = recalled
    }

    public func isWithinEditRecallWindow(now: Date = Date()) -> Bool {
        now.timeIntervalSince(createdAt) < Self.editRecallWindow
    }

    public func isEditable(by userId: UUID, now: Date = Date()) -> Bool {
        !recalled
            && !isSystemNotice
            && senderId == userId
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isWithinEditRecallWindow(now: now)
    }

    public func isRecallable(by userId: UUID, now: Date = Date()) -> Bool {
        !recalled
            && !isSystemNotice
            && senderId == userId
            && isWithinEditRecallWindow(now: now)
    }

    private func copy(
        body: String? = nil,
        reactions: [Reaction]? = nil,
        deliveryStatus: MessageDeliveryStatus? = nil,
        imageAttachments: [MessageImageAttachment]? = nil,
        replyPreview: MessageReplyPreview?? = nil,
        editedAt: Date?? = nil,
        recalled: Bool? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            senderDisplayName: senderDisplayName,
            body: body ?? self.body,
            clientMessageId: clientMessageId,
            createdAt: createdAt,
            sequenceNo: sequenceNo,
            reactions: reactions ?? self.reactions,
            deliveryStatus: deliveryStatus ?? self.deliveryStatus,
            imageAttachments: imageAttachments ?? self.imageAttachments,
            replyPreview: replyPreview ?? self.replyPreview,
            type: type,
            editedAt: editedAt ?? self.editedAt,
            recalled: recalled ?? self.recalled
        )
    }

    public func updating(reactions: [Reaction]) -> ChatMessage {
        copy(reactions: reactions)
    }

    public func updating(deliveryStatus: MessageDeliveryStatus) -> ChatMessage {
        copy(deliveryStatus: deliveryStatus)
    }

    public func updating(body: String) -> ChatMessage {
        copy(body: body)
    }

    public func updating(body: String, editedAt: Date) -> ChatMessage {
        copy(body: body, editedAt: .some(editedAt), recalled: false)
    }

    public func updatingAsRecalled() -> ChatMessage {
        copy(
            body: "",
            reactions: [],
            imageAttachments: [],
            replyPreview: .some(nil),
            editedAt: .some(nil),
            recalled: true
        )
    }

    public var hasImageAttachments: Bool {
        !imageAttachments.isEmpty && !recalled
    }

    /// Aggregated emoji counts for compact display, e.g. ❤️×3 😂×1
    public func reactionCounts() -> [(emoji: String, count: Int)] {
        guard !recalled else { return [] }
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
        guard !recalled else { return [] }
        var emojiOrder: [String] = []
        for reaction in reactions where !emojiOrder.contains(reaction.emoji) {
            emojiOrder.append(reaction.emoji)
        }

        let grouped = Dictionary(grouping: reactions, by: \.emoji)
        let ordered = emojiOrder.map { emoji in
            (emoji: emoji, count: grouped[emoji]?.count ?? 0)
        }

        return isOutgoing ? ordered : ordered.reversed()
    }

    /// Last emoji the given user reacted with on this message (most recent by append order).
    public func lastReactionEmoji(for userId: UUID) -> String? {
        guard !recalled else { return nil }
        return reactions.last(where: { $0.userId == userId })?.emoji
    }
}
