import Foundation

/// Flat image entry for the photo album grid (one row per media item, not per post).
public struct AlbumPhoto: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let postId: UUID
    public let author: UserSummary
    public let mediaURL: URL
    public let thumbnailURL: URL?
    public let mediaType: PostMediaType
    public let sortOrder: Int
    public let createdAt: Date

    public init(
        id: UUID,
        postId: UUID,
        author: UserSummary,
        mediaURL: URL,
        thumbnailURL: URL?,
        mediaType: PostMediaType,
        sortOrder: Int,
        createdAt: Date
    ) {
        self.id = id
        self.postId = postId
        self.author = author
        self.mediaURL = mediaURL
        self.thumbnailURL = thumbnailURL
        self.mediaType = mediaType
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
