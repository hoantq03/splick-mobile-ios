import ImageIO
import Nuke
import UIKit

enum GIFAnimatedImageFactory {
    static func uiImage(from container: ImageContainer, maxPixelSize: CGFloat? = nil) -> UIImage {
        if let data = container.data, let animated = animatedImage(from: data, maxPixelSize: maxPixelSize) {
            return animated
        }
        return container.image
    }

    /// Cheap still frame for grids / off-screen placeholders — does not decode the full animation.
    static func firstFrame(from container: ImageContainer, maxPixelSize: CGFloat? = nil) -> UIImage {
        if let data = container.data, let frame = firstFrame(from: data, maxPixelSize: maxPixelSize) {
            return frame
        }
        return container.image
    }

    static func firstFrame(from data: Data, maxPixelSize: CGFloat? = nil) -> UIImage? {
        let maxSide = maxPixelSize.map { max($0, 1) } ?? FeedMediaLayout.decodeMaxPixelSide
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = createThumbnail(at: 0, source: source, maxPixelSize: maxSide) else {
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
            guard let cgImage = createThumbnail(at: 0, source: source, maxPixelSize: maxSide) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }

        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0

        // Keep every frame — skipping frames makes playback look low-FPS / stuttery.
        for index in 0..<frameCount {
            guard let cgImage = createThumbnail(at: index, source: source, maxPixelSize: maxSide) else {
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

    private static func createThumbnail(
        at index: Int,
        source: CGImageSource,
        maxPixelSize: CGFloat
    ) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize),
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
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
