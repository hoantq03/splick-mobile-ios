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
    /// Uses `UIImage.draw` because `size` is already orientation-aware; rotating `cgImage`
    /// with a second size-swap would turn portrait captures into landscape.
    static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Center-crops so the result matches the phone viewport (what the live finder shows).
    static func cropToAspectFill(_ image: UIImage, aspectRatio: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 1, size.height > 1, aspectRatio > 0 else { return image }
        let imageAspect = size.width / size.height
        if abs(imageAspect - aspectRatio) < 0.01 { return image }

        let crop: CGRect
        if imageAspect > aspectRatio {
            let width = size.height * aspectRatio
            crop = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        } else {
            let height = size.width / aspectRatio
            crop = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        }

        let scale = image.scale
        let pixelCrop = CGRect(
            x: crop.origin.x * scale,
            y: crop.origin.y * scale,
            width: crop.width * scale,
            height: crop.height * scale
        ).integral
        guard let cgImage = image.cgImage?.cropping(to: pixelCrop) else { return image }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

