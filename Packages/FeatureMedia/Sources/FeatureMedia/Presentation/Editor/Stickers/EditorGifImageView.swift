import ImageIO
import SwiftUI
import UIKit

enum EditorGifStyle {
    static let cornerRatio: CGFloat = 0.16

    static func cornerRadius(for size: CGSize) -> CGFloat {
        min(size.width, size.height) * cornerRatio
    }
}

enum EditorGifDecoder {
    private static let maxAnimatedFrames = 24

    static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        if frameCount == 1 {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }

        let step = max(1, frameCount / maxAnimatedFrames)
        var images: [UIImage] = []
        var duration: TimeInterval = 0

        var index = 0
        while index < frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) {
                images.append(UIImage(cgImage: cgImage))
                duration += frameDelay(source: source, index: index) * TimeInterval(step)
            }
            index += step
        }

        guard !images.isEmpty else { return firstFrame(from: data, scale: 1) }
        if images.count == 1 {
            return images[0]
        }
        return UIImage.animatedImage(with: images, duration: max(duration, 0.1))
    }

    static func firstFrame(from data: Data, scale: CGFloat = 1) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    static func isGif(_ data: Data) -> Bool {
        data.starts(with: [0x47, 0x49, 0x46]) // GIF
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

    func makeUIView(context: Context) -> BoundedAnimatedImageView {
        BoundedAnimatedImageView()
    }

    func updateUIView(_ view: BoundedAnimatedImageView, context: Context) {
        guard context.coordinator.loadedData != data else { return }
        context.coordinator.loadedData = data
        view.imageView.image = EditorGifDecoder.animatedImage(from: data)
            ?? EditorGifDecoder.firstFrame(from: data)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BoundedAnimatedImageView, context: Context) -> CGSize {
        let maxSide: CGFloat = 120
        let proposedWidth = proposal.width ?? maxSide
        let proposedHeight = proposal.height ?? maxSide
        if proposedWidth.isFinite, proposedWidth > maxSide,
           proposedHeight.isFinite, proposedHeight <= maxSide {
            return CGSize(width: proposedWidth, height: proposedHeight)
        }
        return CGSize(
            width: min(proposedWidth.isFinite ? proposedWidth : maxSide, maxSide),
            height: min(proposedHeight.isFinite ? proposedHeight : maxSide, maxSide)
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadedData: Data?
    }
}

final class BoundedAnimatedImageView: UIView {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 120, height: 120)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = EditorGifStyle.cornerRadius(for: bounds.size)
        layer.cornerRadius = radius
        imageView.layer.cornerRadius = radius
    }
}
