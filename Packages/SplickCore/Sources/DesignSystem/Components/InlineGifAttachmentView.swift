import Nuke
import SwiftUI
import UIKit

/// Inline GIF that preserves the full frame at a fixed fraction of screen width.
public struct InlineGifAttachmentView: View {
    public let url: URL
    public var widthFraction: CGFloat
    public var cornerRadius: CGFloat

    @State private var pixelAspectRatio: CGFloat?

    public init(
        url: URL,
        widthFraction: CGFloat = 1.0 / 3.0,
        cornerRadius: CGFloat = 8
    ) {
        self.url = url
        self.widthFraction = widthFraction
        self.cornerRadius = cornerRadius
    }

    private var targetWidth: CGFloat {
        max(UIScreen.main.bounds.width * widthFraction, 1)
    }

    public var body: some View {
        Group {
            if let pixelAspectRatio, pixelAspectRatio > 0 {
                AnimatedRemoteImage(
                    url: url,
                    contentMode: .fit,
                    maxPixelSize: RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: targetWidth)
                )
                .frame(
                    width: targetWidth,
                    height: targetWidth / pixelAspectRatio
                )
                .clipped()
            } else {
                loadingPlaceholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: url) {
            await resolveAspectRatio()
        }
    }

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(SplickTheme.Colors.tertiaryBackground.opacity(0.45))
            .frame(width: targetWidth, height: targetWidth * 0.75)
            .overlay {
                ProgressView()
                    .controlSize(.small)
            }
    }

    @MainActor
    private func resolveAspectRatio() async {
        pixelAspectRatio = nil

        let maxPixelSize = RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: targetWidth)
        let request = RemoteImageRequestFactory.boundedRequest(
            url: url,
            maxPixelWidth: maxPixelSize
        )

        let image: UIImage? = await withCheckedContinuation { continuation in
            _ = ImagePipeline.shared.loadImage(with: request) { result in
                switch result {
                case .success(let response):
                    let uiImage = GIFAnimatedImageFactory.uiImage(
                        from: response.container,
                        maxPixelSize: maxPixelSize
                    )
                    continuation.resume(returning: uiImage)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }

        guard !Task.isCancelled else { return }
        guard let image, image.size.width > 0, image.size.height > 0 else { return }
        pixelAspectRatio = image.size.width / image.size.height
    }
}
