import SwiftUI
import UIKit

enum EditorStickerRenderer {
    static func baseSize(for kind: EditorStickerKind, gifData: Data? = nil) -> CGSize {
        switch kind {
        case .symbol, .emoji:
            return CGSize(width: 72, height: 72)
        case .gif, .image:
            if let gifData, let image = EditorGifDecoder.firstFrame(from: gifData) ?? UIImage(data: gifData) {
                let maxSide = max(max(image.size.width, image.size.height), 1)
                let ratio = 120 / maxSide
                return CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            }
            return CGSize(width: 120, height: 120)
        case .widget:
            return EditorWidgetLayout.size
        }
    }

    @MainActor
    static func render(
        _ kind: EditorStickerKind,
        targetPixelSize: CGSize,
        gifData: Data? = nil
    ) -> UIImage? {
        guard targetPixelSize.width > 0, targetPixelSize.height > 0 else { return nil }

        if case .gif = kind, let gifData {
            return renderGif(data: gifData, targetPixelSize: targetPixelSize, rounded: true)
        }
        if case .image = kind, let gifData,
           let image = EditorGifDecoder.firstFrame(from: gifData) ?? UIImage(data: gifData) {
            return renderStill(image, targetPixelSize: targetPixelSize)
        }

        let layoutSize = baseSize(for: kind, gifData: gifData)
        let content = EditorStickerContentView(kind: kind, gifData: gifData)
            .frame(width: layoutSize.width, height: layoutSize.height)
            .fixedSize(horizontal: true, vertical: true)
            .environment(\.colorScheme, .dark)

        let swiftRenderer = ImageRenderer(content: content)
        swiftRenderer.isOpaque = false
        let scaleFactor = targetPixelSize.width / max(layoutSize.width, 1)
        swiftRenderer.scale = max(scaleFactor, 2)

        guard var image = swiftRenderer.uiImage else { return nil }

        // Normalize to exact pixel dimensions — avoids blurry interpolation on export.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetPixelSize, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            let drawRect = CGRect(origin: .zero, size: targetPixelSize)
            if let cgImage = image.cgImage {
                context.cgContext.draw(cgImage, in: drawRect)
            } else {
                image.draw(in: drawRect)
            }
        }
    }

    private static func renderGif(data: Data, targetPixelSize: CGSize, rounded: Bool) -> UIImage? {
        guard let image = EditorGifDecoder.firstFrame(from: data, scale: 1) else { return nil }
        return renderStill(image, targetPixelSize: targetPixelSize, rounded: rounded)
    }

    private static func renderStill(_ image: UIImage, targetPixelSize: CGSize, rounded: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetPixelSize, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            let drawRect = CGRect(origin: .zero, size: targetPixelSize)
            if rounded {
                let radius = EditorGifStyle.cornerRadius(for: targetPixelSize)
                UIBezierPath(roundedRect: drawRect, cornerRadius: radius).addClip()
            }
            image.draw(in: drawRect)
        }
    }
}
