import Foundation
import UIKit
import Common

public enum MediaImagePayload {
    /// JPEG export for avatars; enforces backend 5 MB avatar limit.
    public static func jpegAvatarData(from image: UIImage, compressionQuality: CGFloat = AppConstants.Media.compressionQuality) throws -> (data: Data, mimeType: String) {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw AppError.validation("Could not process the photo.")
        }
        guard data.count <= AppConstants.Media.maxAvatarSizeBytes else {
            throw AppError.validation("Image exceeds maximum size of 5 MB")
        }
        return (data, "image/jpeg")
    }

    /// Downscales then JPEG-encodes for comment / payment-evidence uploads (10 MB client cap).
    public static func jpegUploadData(
        from image: UIImage,
        maxSide: CGFloat = AppConstants.Media.maxUploadLongSide,
        maxBytes: Int = AppConstants.Media.maxImageSizeBytes,
        compressionQuality: CGFloat = AppConstants.Media.compressionQuality
    ) throws -> Data {
        var side = max(maxSide, 640)
        var working = downsampled(image, maxSide: side)
        var quality = compressionQuality
        guard var data = working.jpegData(compressionQuality: quality) else {
            throw AppError.validation("Could not process the photo.")
        }
        while data.count > maxBytes, quality > 0.4 {
            quality -= 0.1
            guard let next = working.jpegData(compressionQuality: quality) else { break }
            data = next
        }
        while data.count > maxBytes, side > 640 {
            side = max(side * 0.75, 640)
            working = downsampled(image, maxSide: side)
            guard let next = working.jpegData(compressionQuality: 0.4) else { break }
            data = next
        }
        guard data.count <= maxBytes else {
            throw AppError.validation("Image exceeds maximum allowed size")
        }
        return data
    }

    public static func downsampled(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
