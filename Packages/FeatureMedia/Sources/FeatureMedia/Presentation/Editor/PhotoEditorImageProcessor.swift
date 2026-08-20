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

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
