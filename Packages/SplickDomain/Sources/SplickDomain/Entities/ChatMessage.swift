import Foundation

public struct ChatMessage: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let conversationId: UUID
    public let senderId: UUID
    public let body: String
    public let clientMessageId: UUID
    public let createdAt: Date

    public init(
        id: UUID,
        conversationId: UUID,
        senderId: UUID,
        body: String,
        clientMessageId: UUID,
        createdAt: Date
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.body = body
        self.clientMessageId = clientMessageId
        self.createdAt = createdAt
    }
}
