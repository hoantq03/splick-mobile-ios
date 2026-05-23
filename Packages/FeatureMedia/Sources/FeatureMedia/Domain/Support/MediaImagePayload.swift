import Foundation
import UIKit
import Common

enum MediaImagePayload {
    /// JPEG export for avatars; enforces backend 5 MB avatar limit.
    static func jpegAvatarData(from image: UIImage, compressionQuality: CGFloat = AppConstants.Media.compressionQuality) throws -> (data: Data, mimeType: String) {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw AppError.validation("Could not process the photo.")
        }
        guard data.count <= AppConstants.Media.maxAvatarSizeBytes else {
            throw AppError.validation("Image exceeds maximum size of 5 MB")
        }
        return (data, "image/jpeg")
    }
}
