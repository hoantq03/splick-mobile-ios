import Foundation
import SplickDomain

public struct PostEditRevision: Identifiable, Sendable, Equatable {
    public var id: Date { editedAt }
    public let editedAt: Date
    public let caption: String?
    public let mediaItems: [PostMediaItem]
    public let audience: PostAudience?
    public let companions: [UserSummary]?
    public let revisionNumber: Int?

    public init(
        editedAt: Date,
        caption: String?,
        mediaItems: [PostMediaItem],
        audience: PostAudience? = nil,
        companions: [UserSummary]? = nil,
        revisionNumber: Int? = nil
    ) {
        self.editedAt = editedAt
        self.caption = caption
        self.mediaItems = mediaItems
        self.audience = audience
        self.companions = companions
        self.revisionNumber = revisionNumber
    }
}

public struct UpdatePostInput: Sendable {
    public let postId: UUID
    public let caption: String?
    public let mediaItems: [UpdatePostMediaItem]
    public let audience: PostAudience
    public let companionIds: [UUID]

    public init(
        postId: UUID,
        caption: String?,
        mediaItems: [UpdatePostMediaItem],
        audience: PostAudience,
        companionIds: [UUID]
    ) {
        self.postId = postId
        self.caption = caption
        self.mediaItems = mediaItems
        self.audience = audience
        self.companionIds = companionIds
    }
}

public enum UpdatePostMediaItem: Sendable {
    case existing(PostMediaItem)
    case uploaded(data: Data, mimeType: String, mediaType: PostMediaType, videoDurationSeconds: Int?)
}
