import Foundation
import UIKit
import Common

public protocol UploadPaymentQrUseCaseProtocol: Sendable {
    func execute(image: UIImage) async throws -> MediaUploadResult
}

public final class UploadPaymentQrUseCase: UploadPaymentQrUseCaseProtocol, Sendable {
    private let repository: MediaRepositoryProtocol

    public init(repository: MediaRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(image: UIImage) async throws -> MediaUploadResult {
        let payload = try MediaImagePayload.jpegAvatarData(from: image)
        guard payload.data.count <= AppConstants.Media.maxAvatarSizeBytes else {
            throw AppError.validation("Image exceeds maximum size of 5 MB")
        }
        return try await repository.uploadImage(
            data: payload.data,
            mimeType: payload.mimeType,
            purpose: .userPaymentQr,
            groupId: nil
        )
    }
}
