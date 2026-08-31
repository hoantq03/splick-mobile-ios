import Foundation

public struct MessageEditDraft: Equatable, Sendable {
    public let messageId: UUID
    public let originalBody: String

    public init(messageId: UUID, originalBody: String) {
        self.messageId = messageId
        self.originalBody = originalBody
    }
}
