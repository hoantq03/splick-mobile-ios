import Foundation
import UIKit
import Common

public protocol UploadGroupAvatarUseCaseProtocol: Sendable {
    func execute(image: UIImage, groupId: UUID) async throws -> MediaUploadResult
    func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult
}

public final class UploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol, Sendable {
    private let repository: MediaRepositoryProtocol

    public init(repository: MediaRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(image: UIImage, groupId: UUID) async throws -> MediaUploadResult {
        let payload = try MediaImagePayload.jpegAvatarData(from: image)
        return try await execute(imageData: payload.data, groupId: groupId) // re-validates size; same mime
    }

    public func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult {
        guard imageData.count <= AppConstants.Media.maxAvatarSizeBytes else {
            throw AppError.validation("Image exceeds maximum size of 5 MB")
        }
        return try await repository.uploadImage(
            data: imageData,
            mimeType: "image/jpeg",
            purpose: .groupAvatar,
            groupId: groupId
        )
    }
}
