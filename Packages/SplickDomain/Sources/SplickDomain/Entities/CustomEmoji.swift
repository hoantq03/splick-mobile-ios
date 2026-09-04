import Foundation

public struct CustomEmoji: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let ownerId: UUID?
    public let shortcode: String
    public let mediaUrl: URL
    public let createdAt: Date

    public init(
        id: UUID,
        ownerId: UUID?,
        shortcode: String,
        mediaUrl: URL,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerId = ownerId
        self.shortcode = shortcode
        self.mediaUrl = mediaUrl
        self.createdAt = createdAt
    }

    public var colonCode: String { ":\(shortcode):" }
}
