import Foundation
import UIKit
import Common

public protocol UploadUserAvatarUseCaseProtocol: Sendable {
    func execute(image: UIImage) async throws -> MediaUploadResult
    func execute(imageData: Data, mimeType: String) async throws -> MediaUploadResult
}

public final class UploadUserAvatarUseCase: UploadUserAvatarUseCaseProtocol, Sendable {
    private let repository: MediaRepositoryProtocol

    public init(repository: MediaRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(image: UIImage) async throws -> MediaUploadResult {
        let payload = try MediaImagePayload.jpegAvatarData(from: image)
        return try await execute(imageData: payload.data, mimeType: payload.mimeType)
    }

    public func execute(imageData: Data, mimeType: String) async throws -> MediaUploadResult {
        guard imageData.count <= AppConstants.Media.maxAvatarSizeBytes else {
            throw AppError.validation("Image exceeds maximum size of 5 MB")
        }
        return try await repository.uploadImage(
            data: imageData,
            mimeType: mimeType,
            purpose: .userAvatar,
            groupId: nil
        )
    }
}
