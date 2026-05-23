import Foundation
import Networking
import Common

public final class MediaRepository: MediaRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol
    private let presignedUploadClient: PresignedUploadClientProtocol

    public init(
        apiClient: APIClientProtocol,
        presignedUploadClient: PresignedUploadClientProtocol = PresignedUploadClient()
    ) {
        self.apiClient = apiClient
        self.presignedUploadClient = presignedUploadClient
    }

    public func uploadImage(
        data: Data,
        mimeType: String,
        purpose: MediaUploadPurpose,
        groupId: UUID?
    ) async throws -> MediaUploadResult {
        let context = groupId.map { UploadContextDTO(groupId: $0) }

        let initiateBody = InitiateUploadRequestDTO(
            purpose: purpose.rawValue,
            contentType: mimeType,
            contentLength: data.count,
            context: context
        )

        let initiated: InitiateUploadResponseDTO = try await apiClient.request(
            MediaEndpoint.initiateUpload(initiateBody)
        )

        try await presignedUploadClient.put(
            data: data,
            to: initiated.presignedUrl,
            headers: initiated.requiredHeaders
        )

        let completed: MediaUploadResponseDTO = try await apiClient.request(
            MediaEndpoint.completeUpload(uploadId: initiated.uploadId, body: nil)
        )

        return MediaUploadResult(
            id: completed.id,
            url: URL(string: completed.url)!,
            thumbnailURL: completed.thumbnailUrl.flatMap(URL.init(string:)),
            sizeBytes: completed.sizeBytes
        )
    }

    public func deleteMedia(id: UUID) async throws {
        try await apiClient.request(MediaEndpoint.delete(id: id))
    }
}
