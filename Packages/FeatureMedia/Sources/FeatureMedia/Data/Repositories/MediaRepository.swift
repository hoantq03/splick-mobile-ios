import Foundation
import Networking
import Common

public final class MediaRepository: MediaRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func uploadImage(data: Data, mimeType: String) async throws -> MediaUploadResult {
        let dto: MediaUploadResponseDTO = try await apiClient.upload(
            MediaEndpoint.upload,
            data: data,
            mimeType: mimeType
        )
        return MediaUploadResult(
            id: dto.id,
            url: URL(string: dto.url)!,
            thumbnailURL: dto.thumbnailUrl.flatMap(URL.init(string:)),
            sizeBytes: dto.sizeBytes
        )
    }

    public func deleteMedia(id: UUID) async throws {
        try await apiClient.request(MediaEndpoint.delete(id: id))
    }
}
