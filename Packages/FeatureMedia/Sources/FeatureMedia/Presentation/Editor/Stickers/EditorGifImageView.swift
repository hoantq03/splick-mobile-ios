import ImageIO
import SwiftUI
import UIKit

enum EditorGifDecoder {
    static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        if frameCount == 1 {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }

        var images: [UIImage] = []
        var duration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))
            duration += frameDelay(source: source, index: index)
        }

        guard !images.isEmpty else { return nil }
        return UIImage.animatedImage(with: images, duration: max(duration, 0.1))
    }

    static func firstFrame(from data: Data, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    static func isGif(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String? else { return false }
        return type.lowercased() == "com.compuserve.gif"
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifInfo = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }

        let unclamped = gifInfo[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clamped = gifInfo[kCGImagePropertyGIFDelayTime] as? TimeInterval
        let delay = unclamped ?? clamped ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }
}

struct EditorGifImageView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.image = EditorGifDecoder.animatedImage(from: data)
    }
}
