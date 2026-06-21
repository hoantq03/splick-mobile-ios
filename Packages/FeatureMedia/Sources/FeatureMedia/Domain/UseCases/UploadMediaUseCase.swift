import Foundation
import Common
import SplickDomain

public protocol UploadMediaUseCaseProtocol: Sendable {
    func execute(imageData: Data) async throws -> MediaUploadResult
    func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult
    func execute(
        imageData: Data,
        mimeType: String,
        purpose: MediaUploadPurpose,
        groupId: UUID?
    ) async throws -> MediaUploadResult
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
        try await UploadUserAvatarUseCase(repository: repository).execute(imageData: imageData, mimeType: "image/jpeg")
    }

    public func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult {
        try await execute(
            imageData: imageData,
            mimeType: "image/jpeg",
            purpose: .groupAvatar,
            groupId: groupId
        )
    }

    public func execute(
        imageData: Data,
        mimeType: String,
        purpose: MediaUploadPurpose,
        groupId: UUID?
    ) async throws -> MediaUploadResult {
        let maxBytes = purpose == .groupCustomEmoji
            ? AppConstants.Media.maxCustomEmojiSizeBytes
            : AppConstants.Media.maxAvatarSizeBytes
        guard imageData.count <= maxBytes else {
            throw AppError.validation("Image exceeds maximum allowed size")
        }
        return try await repository.uploadImage(
            data: imageData,
            mimeType: mimeType,
            purpose: purpose,
            groupId: groupId
        )
    }
}
