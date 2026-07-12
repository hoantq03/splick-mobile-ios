import SwiftUI
import UIKit
import Nuke

/// Renders remote animated GIF/WebP via Nuke cache + `UIImageView` playback.
///
/// Nuke 12 `LazyImage` uses `SwiftUI.Image`, which only shows the first GIF frame.
/// This view loads via `ImagePipeline` and decodes GIF frames with ImageIO **off the main thread**.
///
/// Important: animated loads must **not** use Nuke thumbnail options — thumbnails drop
/// `container.data`, which makes `UIImage.animatedImage` impossible.
public struct AnimatedRemoteImage: UIViewRepresentable {
    private let url: URL?
    private let contentMode: ContentMode
    private let maxPixelSize: CGFloat?
    private let isAnimating: Bool
    private let onPixelSize: ((CGSize) -> Void)?

    public init(
        url: URL?,
        contentMode: ContentMode = .fill,
        maxPixelSize: CGFloat? = nil,
        isAnimating: Bool = true,
        onPixelSize: ((CGSize) -> Void)? = nil
    ) {
        self.url = url
        self.contentMode = contentMode
        self.maxPixelSize = maxPixelSize
        self.isAnimating = isAnimating
        self.onPixelSize = onPixelSize
    }

    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true
        // Prevent UIViewRepresentable from expanding unbounded in stacks.
        container.setContentHuggingPriority(.required, for: .horizontal)
        container.setContentHuggingPriority(.required, for: .vertical)
        container.setContentCompressionResistancePriority(.required, for: .horizontal)
        container.setContentCompressionResistancePriority(.required, for: .vertical)

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.contentMode = uiContentMode
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.imageView = imageView
        context.coordinator.onPixelSize = onPixelSize
        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.imageView?.contentMode = uiContentMode
        context.coordinator.onPixelSize = onPixelSize
        context.coordinator.update(
            url: url,
            maxPixelSize: maxPixelSize,
            isAnimating: isAnimating
        )
    }

    public static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cancel()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var uiContentMode: UIView.ContentMode {
        contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
    }

    public final class Coordinator {
        private var task: ImageTask?
        private var loadedURL: URL?
        private var loadedMaxPixelSize: CGFloat?
        private var loadedWantsAnimation = false
        private var animatedImage: UIImage?
        private var staticImage: UIImage?
        private var decodeGeneration = 0
        private var reportedSize: CGSize?
        fileprivate weak var imageView: UIImageView?
        fileprivate var onPixelSize: ((CGSize) -> Void)?

        func update(url: URL?, maxPixelSize: CGFloat?, isAnimating: Bool) {
            guard let imageView else { return }

            guard let url else {
                cancel()
                loadedURL = nil
                loadedMaxPixelSize = nil
                loadedWantsAnimation = false
                animatedImage = nil
                staticImage = nil
                reportedSize = nil
                imageView.image = nil
                return
            }

            let sameRequest = loadedURL == url && loadedMaxPixelSize == maxPixelSize
            if sameRequest {
                if isAnimating == loadedWantsAnimation {
                    return
                }
                if isAnimating, let animatedImage {
                    loadedWantsAnimation = true
                    imageView.image = animatedImage
                    return
                }
                if !isAnimating, let staticImage {
                    loadedWantsAnimation = false
                    imageView.image = staticImage
                    return
                }
                if !isAnimating, let animatedImage {
                    loadedWantsAnimation = false
                    let still = Self.stillFrame(from: animatedImage) ?? animatedImage
                    staticImage = still
                    imageView.image = still
                    return
                }
            }

            load(url: url, maxPixelSize: maxPixelSize, isAnimating: isAnimating)
        }

        func cancel() {
            task?.cancel()
            task = nil
            decodeGeneration += 1
        }

        private func reportSizeIfNeeded(from image: UIImage) {
            let size = image.size
            guard size.width > 0, size.height > 0 else { return }
            guard reportedSize != size else { return }
            reportedSize = size
            onPixelSize?(size)
        }

        private func load(url: URL, maxPixelSize: CGFloat?, isAnimating: Bool) {
            task?.cancel()
            task = nil
            decodeGeneration += 1
            let generation = decodeGeneration

            loadedURL = url
            loadedMaxPixelSize = maxPixelSize
            loadedWantsAnimation = isAnimating
            reportedSize = nil

            // Thumbnail pipeline strips GIF data → animation becomes impossible.
            let request: ImageRequest
            if isAnimating {
                request = ImageRequest(url: url)
            } else if let maxPixelSize, maxPixelSize > 0 {
                request = RemoteImageRequestFactory.boundedRequest(url: url, maxPixelWidth: maxPixelSize)
            } else {
                request = ImageRequest(url: url)
            }

            task = ImagePipeline.shared.loadImage(with: request) { [weak self] result in
                guard let self else { return }
                guard self.loadedURL == url, generation == self.decodeGeneration else { return }

                switch result {
                case .success(let response):
                    let container = response.container
                    let placeholder = container.image

                    DispatchQueue.main.async {
                        guard self.loadedURL == url, generation == self.decodeGeneration else { return }
                        if self.imageView?.image == nil {
                            self.staticImage = placeholder
                            self.imageView?.image = placeholder
                        }
                        self.reportSizeIfNeeded(from: placeholder)
                    }

                    DispatchQueue.global(qos: .userInitiated).async {
                        let animated: UIImage?
                        let still: UIImage
                        if isAnimating {
                            let decoded = GIFAnimatedImageFactory.uiImage(
                                from: container,
                                maxPixelSize: maxPixelSize
                            )
                            animated = decoded
                            still = Self.stillFrame(from: decoded)
                                ?? GIFAnimatedImageFactory.firstFrame(
                                    from: container,
                                    maxPixelSize: maxPixelSize
                                )
                        } else {
                            animated = nil
                            still = GIFAnimatedImageFactory.firstFrame(
                                from: container,
                                maxPixelSize: maxPixelSize
                            )
                        }

                        DispatchQueue.main.async {
                            guard self.loadedURL == url, generation == self.decodeGeneration else { return }
                            self.animatedImage = animated
                            self.staticImage = still
                            let displayed = self.loadedWantsAnimation ? (animated ?? still) : still
                            self.imageView?.image = displayed
                            self.reportSizeIfNeeded(from: displayed)
                        }
                    }
                case .failure:
                    DispatchQueue.main.async {
                        guard self.loadedURL == url, generation == self.decodeGeneration else { return }
                        self.imageView?.image = nil
                    }
                }
            }
        }

        private static func stillFrame(from image: UIImage) -> UIImage? {
            guard let frame = image.images?.first else { return nil }
            if let cgImage = frame.cgImage {
                return UIImage(cgImage: cgImage, scale: frame.scale, orientation: frame.imageOrientation)
            }
            return frame
        }
    }
}
