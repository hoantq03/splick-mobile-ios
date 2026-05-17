import Foundation
import SplickDomain

public struct MediaUploadResult: Equatable, Sendable {
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

public protocol MediaRepositoryProtocol: Sendable {
    func uploadImage(data: Data, mimeType: String) async throws -> MediaUploadResult
    func deleteMedia(id: UUID) async throws
}
