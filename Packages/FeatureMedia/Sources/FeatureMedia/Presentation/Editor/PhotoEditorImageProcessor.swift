import UIKit

enum PhotoEditorImageProcessor {
    struct PreparedImage {
        let editingImage: UIImage
        let originalImage: UIImage
        let exportScale: CGFloat
    }

    static func prepareForEditing(_ image: UIImage) -> PreparedImage {
        let normalized = normalizeOrientation(image)
        return PreparedImage(editingImage: normalized, originalImage: normalized, exportScale: 1)
    }

    /// Bakes EXIF orientation into pixels so `size` matches what is shown on screen.
    static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        guard let cgImage = image.cgImage else { return image }

        let width = image.size.width
        let height = image.size.height
        var transform = CGAffineTransform.identity

        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height).rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0).rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height).rotated(by: -.pi / 2)
        default:
            break
        }

        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0).scaledBy(x: -1, y: 1)
        default:
            break
        }

        let outputSize: CGSize
        let drawRect: CGRect
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            outputSize = CGSize(width: height, height: width)
            drawRect = CGRect(x: 0, y: 0, width: height, height: width)
        default:
            outputSize = CGSize(width: width, height: height)
            drawRect = CGRect(x: 0, y: 0, width: width, height: height)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            context.cgContext.concatenate(transform)
            context.cgContext.draw(cgImage, in: drawRect)
        }
    }
}
