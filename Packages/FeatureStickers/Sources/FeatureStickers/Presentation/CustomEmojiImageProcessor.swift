import UIKit

enum CustomEmojiImageProcessor {
    static let targetSize = CGSize(width: 128, height: 128)

    static func prepareUploadData(from image: UIImage) throws -> (Data, String) {
        let normalized = normalizeOrientation(image)
        guard let square = centerSquareCrop(normalized),
              let resized = resize(square, to: targetSize),
              let data = resized.jpegData(compressionQuality: 0.85)
        else {
            throw CustomEmojiError.imageProcessingFailed
        }
        return (data, "image/jpeg")
    }

    /// Bakes EXIF into pixels so `size` matches what SwiftUI shows.
    static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func centerSquareCrop(_ image: UIImage) -> UIImage? {
        let size = image.size
        guard size.width > 1, size.height > 1, let cgImage = image.cgImage else { return nil }
        let side = min(size.width, size.height)
        let crop = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )
        let scale = image.scale
        let pixelCrop = CGRect(
            x: crop.origin.x * scale,
            y: crop.origin.y * scale,
            width: crop.width * scale,
            height: crop.height * scale
        ).integral
        guard let cropped = cgImage.cropping(to: pixelCrop) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    private static func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
