import Foundation

public struct MessageReplyPreview: Equatable, Hashable, Sendable, Codable {
    public let messageId: UUID
    public let senderId: UUID
    public let senderDisplayName: String?
    public let body: String
    public let hasImageAttachment: Bool

    public init(
        messageId: UUID,
        senderId: UUID,
        senderDisplayName: String?,
        body: String,
        hasImageAttachment: Bool
    ) {
        self.messageId = messageId
        self.senderId = senderId
        self.senderDisplayName = senderDisplayName
        self.body = body
        self.hasImageAttachment = hasImageAttachment
    }
}
