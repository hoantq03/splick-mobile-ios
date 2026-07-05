import Foundation
import CoreGraphics

public struct PostMediaItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let mediaURL: URL
    public let thumbnailURL: URL?
    public let mediaType: PostMediaType
    public let durationSeconds: Int?
    public let widthPx: Int?
    public let heightPx: Int?
    public let sortOrder: Int

    public init(
        id: UUID = UUID(),
        mediaURL: URL,
        thumbnailURL: URL? = nil,
        mediaType: PostMediaType,
        durationSeconds: Int? = nil,
        widthPx: Int? = nil,
        heightPx: Int? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.mediaURL = mediaURL
        self.thumbnailURL = thumbnailURL
        self.mediaType = mediaType
        self.durationSeconds = durationSeconds
        self.widthPx = widthPx
        self.heightPx = heightPx
        self.sortOrder = sortOrder
    }

    /// Width / height of the original media in pixels.
    public var aspectRatio: CGFloat? {
        guard let widthPx, let heightPx, widthPx > 0, heightPx > 0 else { return nil }
        return CGFloat(widthPx) / CGFloat(heightPx)
    }
}
