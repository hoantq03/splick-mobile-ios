import ImageIO
import Nuke
import UIKit

enum GIFAnimatedImageFactory {
    static func uiImage(from container: ImageContainer, maxPixelSize: CGFloat? = nil) -> UIImage {
        if let data = container.data, let animated = animatedImage(from: data, maxPixelSize: maxPixelSize) {
            return animated
        }
        return downscaleUIImage(container.image, maxPixelSize: maxPixelSize) ?? container.image
    }

    /// Cheap still frame for grids / off-screen placeholders — does not decode the full animation.
    static func firstFrame(from container: ImageContainer, maxPixelSize: CGFloat? = nil) -> UIImage {
        if let data = container.data, let frame = firstFrame(from: data, maxPixelSize: maxPixelSize) {
            return frame
        }
        return downscaleUIImage(container.image, maxPixelSize: maxPixelSize) ?? container.image
    }

    static func firstFrame(from data: Data, maxPixelSize: CGFloat? = nil) -> UIImage? {
        let maxSide = maxPixelSize.map { max($0, 1) } ?? FeedMediaLayout.decodeMaxPixelSide
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = createDownscaledFrame(at: 0, source: source, maxPixelSize: maxSide) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    static func animatedImage(from data: Data, maxPixelSize: CGFloat? = nil) -> UIImage? {
        let maxSide = maxPixelSize.map { max($0, 1) } ?? FeedMediaLayout.decodeMaxPixelSide
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else {
            guard let cgImage = createDownscaledFrame(at: 0, source: source, maxPixelSize: maxSide) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }

        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0

        // Keep every frame — skipping frames makes playback look low-FPS / stuttery.
        for index in 0..<frameCount {
            guard let cgImage = createDownscaledFrame(at: index, source: source, maxPixelSize: maxSide) else {
                continue
            }
            images.append(UIImage(cgImage: cgImage))
            totalDuration += frameDuration(at: index, source: source)
        }

        guard !images.isEmpty else {
            return nil
        }

        return UIImage.animatedImage(with: images, duration: max(totalDuration, 0.1))
    }

    /// Decode + CPU downscale. Avoids `CGImageSourceCreateThumbnailAtIndex`, which frequently
    /// logs `CVPixelBufferCreate … RGBA (-6680)` for common sticker/GIF sizes on Simulator.
    private static func createDownscaledFrame(
        at index: Int,
        source: CGImageSource,
        maxPixelSize: CGFloat
    ) -> CGImage? {
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
        ]
        guard let full = CGImageSourceCreateImageAtIndex(source, index, decodeOptions as CFDictionary) else {
            return nil
        }
        return downscaledCGImage(full, maxPixelSize: maxPixelSize)
    }

    private static func downscaleUIImage(_ image: UIImage, maxPixelSize: CGFloat?) -> UIImage? {
        guard let maxPixelSize, maxPixelSize > 0, let cgImage = image.cgImage else { return image }
        guard let scaled = downscaledCGImage(cgImage, maxPixelSize: maxPixelSize) else { return image }
        return UIImage(cgImage: scaled, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func downscaledCGImage(_ image: CGImage, maxPixelSize: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longest = max(width, height)
        guard longest > maxPixelSize, maxPixelSize > 0 else { return image }

        let scale = maxPixelSize / longest
        // Even dimensions reduce CoreVideo row-alignment failures if anything still touches CV.
        var targetWidth = max(2, (width * scale).rounded(.down))
        var targetHeight = max(2, (height * scale).rounded(.down))
        targetWidth = floor(targetWidth / 2) * 2
        targetHeight = floor(targetHeight / 2) * 2

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: targetWidth, height: targetHeight)
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }

    private static func frameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
        let defaultDuration = 0.1
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return defaultDuration
        }

        if let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval,
           unclamped > 0 {
            return unclamped < 0.02 ? 0.1 : unclamped
        }

        if let delay = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval, delay > 0 {
            return delay < 0.02 ? 0.1 : delay
        }

        return defaultDuration
    }
}
