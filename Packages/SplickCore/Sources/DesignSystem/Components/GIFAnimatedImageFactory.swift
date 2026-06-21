import ImageIO
import Nuke
import UIKit

enum GIFAnimatedImageFactory {
    static func uiImage(from container: ImageContainer) -> UIImage {
        if let data = container.data, let animated = animatedImage(from: data) {
            return animated
        }
        return container.image
    }

    static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else {
            return UIImage(data: data)
        }

        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }
            images.append(UIImage(cgImage: cgImage))
            totalDuration += frameDuration(at: index, source: source)
        }

        guard !images.isEmpty else {
            return UIImage(data: data)
        }

        return UIImage.animatedImage(with: images, duration: max(totalDuration, 0.1))
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
            return unclamped
        }

        if let delay = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval, delay > 0 {
            return delay
        }

        return defaultDuration
    }
}
