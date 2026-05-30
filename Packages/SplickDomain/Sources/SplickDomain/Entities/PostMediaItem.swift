import Foundation

public struct PostMediaItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let mediaURL: URL
    public let thumbnailURL: URL?
    public let mediaType: PostMediaType
    public let durationSeconds: Int?
    public let sortOrder: Int

    public init(
        id: UUID = UUID(),
        mediaURL: URL,
        thumbnailURL: URL? = nil,
        mediaType: PostMediaType,
        durationSeconds: Int? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.mediaURL = mediaURL
        self.thumbnailURL = thumbnailURL
        self.mediaType = mediaType
        self.durationSeconds = durationSeconds
        self.sortOrder = sortOrder
    }
}
