import Foundation
import Common

public protocol UploadMediaUseCaseProtocol: Sendable {
    func execute(imageData: Data) async throws -> MediaUploadResult
    func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult
}

public extension UploadMediaUseCaseProtocol {
    func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult {
        try await execute(imageData: imageData)
    }
}

public final class UploadMediaUseCase: UploadMediaUseCaseProtocol, Sendable {
    private let repository: MediaRepositoryProtocol

    public init(repository: MediaRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(imageData: Data) async throws -> MediaUploadResult {
        guard imageData.count <= AppConstants.Media.maxImageSizeBytes else {
            throw AppError.validation("Image exceeds maximum size of 10 MB")
        }

        return try await repository.uploadImage(
            data: imageData,
            mimeType: "image/jpeg",
            purpose: .userAvatar,
            groupId: nil
        )
    }

    public func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult {
        guard imageData.count <= AppConstants.Media.maxImageSizeBytes else {
            throw AppError.validation("Image exceeds maximum size of 10 MB")
        }

        return try await repository.uploadImage(
            data: imageData,
            mimeType: "image/jpeg",
            purpose: .groupAvatar,
            groupId: groupId
        )
    }
}
