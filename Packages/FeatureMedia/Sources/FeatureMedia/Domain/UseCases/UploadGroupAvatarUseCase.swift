import Foundation
import Common

public protocol UploadGroupAvatarUseCaseProtocol: Sendable {
    func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult
}

public final class UploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol, Sendable {
    private let repository: MediaRepositoryProtocol

    public init(repository: MediaRepositoryProtocol) {
        self.repository = repository
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
