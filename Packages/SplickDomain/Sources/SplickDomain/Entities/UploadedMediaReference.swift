import Foundation

/// Media-service upload result at shared module boundaries (feed, messaging compose).
public struct UploadedMediaReference: Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let thumbnailURL: URL?
    public let sizeBytes: Int

    public init(id: UUID, url: URL, thumbnailURL: URL? = nil, sizeBytes: Int) {
        self.id = id
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.sizeBytes = sizeBytes
    }
}
