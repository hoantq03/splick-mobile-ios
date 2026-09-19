import Foundation
import SplickDomain

public struct PostEditRevision: Identifiable, Sendable, Equatable {
    public var id: Date { editedAt }
    public let editedAt: Date
    public let caption: String?
    public let mediaItems: [PostMediaItem]

    public init(editedAt: Date, caption: String?, mediaItems: [PostMediaItem]) {
        self.editedAt = editedAt
        self.caption = caption
        self.mediaItems = mediaItems
    }
}

public struct UpdatePostInput: Sendable {
    public let postId: UUID
    public let caption: String?
    public let mediaItems: [UpdatePostMediaItem]

    public init(postId: UUID, caption: String?, mediaItems: [UpdatePostMediaItem]) {
        self.postId = postId
        self.caption = caption
        self.mediaItems = mediaItems
    }
}

public enum UpdatePostMediaItem: Sendable {
    case existing(PostMediaItem)
    case uploaded(data: Data, mimeType: String, mediaType: PostMediaType, videoDurationSeconds: Int?)
}
