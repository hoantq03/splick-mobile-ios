import SwiftUI
import UIKit
import Nuke

/// Renders remote animated GIF/WebP via Nuke cache + `UIImageView` playback.
///
/// Nuke 12 `LazyImage` uses `SwiftUI.Image`, which only shows the first GIF frame.
/// This view loads via `ImagePipeline` and decodes GIF frames with ImageIO.
public struct AnimatedRemoteImage: UIViewRepresentable {
    private let url: URL?
    private let contentMode: ContentMode
    private let maxPixelSize: CGFloat?

    public init(
        url: URL?,
        contentMode: ContentMode = .fill,
        maxPixelSize: CGFloat? = nil
    ) {
        self.url = url
        self.contentMode = contentMode
        self.maxPixelSize = maxPixelSize
    }

    public func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = uiContentMode
        return imageView
    }

    public func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.contentMode = uiContentMode
        context.coordinator.load(url: url, maxPixelSize: maxPixelSize, into: imageView)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var uiContentMode: UIView.ContentMode {
        contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
    }

    public final class Coordinator {
        private var task: ImageTask?

        func load(url: URL?, maxPixelSize: CGFloat?, into imageView: UIImageView) {
            task?.cancel()
            task = nil

            guard let url else {
                imageView.image = nil
                return
            }

            let request: ImageRequest
            if let maxPixelSize, maxPixelSize > 0 {
                request = RemoteImageRequestFactory.boundedRequest(url: url, maxPixelWidth: maxPixelSize)
            } else {
                request = ImageRequest(url: url)
            }
            task = ImagePipeline.shared.loadImage(with: request) { result in
                switch result {
                case .success(let response):
                    imageView.image = GIFAnimatedImageFactory.uiImage(
                        from: response.container,
                        maxPixelSize: maxPixelSize
                    )
                case .failure:
                    imageView.image = nil
                }
            }
        }
    }
}
