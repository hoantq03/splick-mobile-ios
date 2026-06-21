import Foundation

public struct CustomEmoji: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let groupId: UUID
    public let shortcode: String
    public let mediaUrl: URL
    public let createdBy: UUID?
    public let createdAt: Date

    public init(
        id: UUID,
        groupId: UUID,
        shortcode: String,
        mediaUrl: URL,
        createdBy: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.groupId = groupId
        self.shortcode = shortcode
        self.mediaUrl = mediaUrl
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    public var colonCode: String { ":\(shortcode):" }
}
