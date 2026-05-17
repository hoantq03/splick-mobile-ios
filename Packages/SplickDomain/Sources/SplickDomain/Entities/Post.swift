import Foundation

public struct Post: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let author: UserSummary
    public let imageURL: URL
    public let thumbnailURL: URL?
    public let caption: String?
    public let reactions: [Reaction]
    public let groupId: UUID?
    public let createdAt: Date

    public init(
        id: UUID,
        author: UserSummary,
        imageURL: URL,
        thumbnailURL: URL? = nil,
        caption: String? = nil,
        reactions: [Reaction] = [],
        groupId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.author = author
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.reactions = reactions
        self.groupId = groupId
        self.createdAt = createdAt
    }

    public var reactionCount: Int { reactions.count }
}

public struct Reaction: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let emoji: String
    public let userId: UUID
    public let createdAt: Date

    public init(id: UUID, emoji: String, userId: UUID, createdAt: Date = .now) {
        self.id = id
        self.emoji = emoji
        self.userId = userId
        self.createdAt = createdAt
    }
}
