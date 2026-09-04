import Foundation

public struct MessageReplyDraft: Equatable, Sendable {
    public let messageId: UUID
    public let senderId: UUID
    public let senderDisplayName: String
    public let bodySnippet: String
    public let hasImageAttachment: Bool

    public init(
        messageId: UUID,
        senderId: UUID,
        senderDisplayName: String,
        bodySnippet: String,
        hasImageAttachment: Bool
    ) {
        self.messageId = messageId
        self.senderId = senderId
        self.senderDisplayName = senderDisplayName
        self.bodySnippet = bodySnippet
        self.hasImageAttachment = hasImageAttachment
    }

    public var replyPreview: MessageReplyPreview {
        MessageReplyPreview(
            messageId: messageId,
            senderId: senderId,
            senderDisplayName: senderDisplayName,
            body: bodySnippet,
            hasImageAttachment: hasImageAttachment
        )
    }
}
