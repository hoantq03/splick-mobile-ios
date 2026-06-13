import Foundation
import SplickDomain

public struct ConversationPeer: Equatable, Hashable, Sendable {
    public let userId: UUID
    public let username: String
    public let displayName: String?
    public let avatarUrl: String?

    public var displayTitle: String {
        displayName?.isEmpty == false ? displayName! : username
    }

    public init(userId: UUID, username: String, displayName: String?, avatarUrl: String?) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
    }
}

public struct Conversation: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let unreadCount: Int
    public let peer: ConversationPeer?
    public let lastMessage: ChatMessage?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        unreadCount: Int,
        peer: ConversationPeer?,
        lastMessage: ChatMessage?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.unreadCount = unreadCount
        self.peer = peer
        self.lastMessage = lastMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
