import Foundation

public struct ChatThreadRoute: Hashable, Sendable {
    public let conversation: Conversation
    public let highlightMessageId: UUID?

    public init(conversation: Conversation, highlightMessageId: UUID? = nil) {
        self.conversation = conversation
        self.highlightMessageId = highlightMessageId
    }
}
