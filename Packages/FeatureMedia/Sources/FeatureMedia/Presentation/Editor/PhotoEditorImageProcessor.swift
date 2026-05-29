import UIKit

enum PhotoEditorImageProcessor {
    private static let maxEditDimension: CGFloat = 2048

    struct PreparedImage {
        let editingImage: UIImage
        let originalImage: UIImage
        let exportScale: CGFloat
    }

    static func prepareForEditing(_ image: UIImage) -> PreparedImage {
        let normalized = normalizeOrientation(image)
        let pixelWidth = normalized.size.width * normalized.scale
        let pixelHeight = normalized.size.height * normalized.scale
        let longest = max(pixelWidth, pixelHeight)

        guard longest > maxEditDimension else {
            return PreparedImage(editingImage: normalized, originalImage: normalized, exportScale: 1)
        }

        let ratio = maxEditDimension / longest
        let targetPixelSize = CGSize(
            width: floor(pixelWidth * ratio),
            height: floor(pixelHeight * ratio)
        )
        let targetPointSize = CGSize(
            width: targetPixelSize.width / normalized.scale,
            height: targetPixelSize.height / normalized.scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = normalized.scale
        format.opaque = true

        let resized = UIGraphicsImageRenderer(size: targetPointSize, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: targetPointSize))
        }

        return PreparedImage(
            editingImage: resized,
            originalImage: normalized,
            exportScale: longest / maxEditDimension
        )
    }

    static func upscaleForExport(_ edited: UIImage, prepared: PreparedImage) -> UIImage {
        guard prepared.exportScale > 1.01 else { return edited }

        let targetSize = prepared.originalImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = prepared.originalImage.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            edited.draw(in: CGRect(origin: .zero, size: targetSize))
        }
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
