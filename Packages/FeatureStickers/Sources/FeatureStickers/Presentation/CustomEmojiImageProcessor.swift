import UIKit

enum CustomEmojiImageProcessor {
    static let targetSize = CGSize(width: 128, height: 128)

    static func prepareUploadData(from image: UIImage) throws -> (Data, String) {
        guard let square = centerSquareCrop(image),
              let resized = resize(square, to: targetSize),
              let data = resized.jpegData(compressionQuality: 0.85)
        else {
            throw CustomEmojiError.imageProcessingFailed
        }
        return (data, "image/jpeg")
    }

    private static func centerSquareCrop(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let side = min(width, height)
        let originX = (width - side) / 2
        let originY = (height - side) / 2
        let rect = CGRect(x: originX, y: originY, width: side, height: side)
        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
