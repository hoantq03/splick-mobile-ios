import Foundation

public struct MessageImageAttachment: Equatable, Hashable, Sendable, Codable {
    public let mediaId: UUID?
    public let url: URL
    public let thumbnailURL: URL?

    public init(mediaId: UUID?, url: URL, thumbnailURL: URL?) {
        self.mediaId = mediaId
        self.url = url
        self.thumbnailURL = thumbnailURL
    }
}
