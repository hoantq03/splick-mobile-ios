import SwiftUI
import UIKit
import Nuke
import NukeUI

/// Drop-in replacement for `AsyncImage` backed by Nuke memory + disk cache.
/// Nuke is an implementation detail — feature packages import `DesignSystem` only.
/// Uses `.onDisappear(.lowerPriority)` so scroll-off does not cancel in-flight downloads;
/// completed bytes stay in DataCache and are not re-fetched from the network.
public struct RemoteImage<Content: View>: View {
    private let url: URL?
    private let maxPixelWidth: CGFloat?
    private let maxPixelDimensions: CGSize?
    private let content: (AsyncImagePhase) -> Content

    public init(
        url: URL?,
        maxPixelSize: CGFloat? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.maxPixelWidth = maxPixelSize
        self.maxPixelDimensions = nil
        self.content = content
    }

    public init(
        url: URL?,
        maxPixelDimensions: CGSize?,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.maxPixelWidth = nil
        self.maxPixelDimensions = maxPixelDimensions
        self.content = content
    }

    public var body: some View {
        LazyImage(request: imageRequest) { state in
            if let image = state.image {
                content(.success(image))
            } else if let error = state.error {
                content(.failure(error))
            } else {
                content(.empty)
            }
        }
        .onDisappear(.lowerPriority)
    }

    private var imageRequest: ImageRequest? {
        guard let url else { return nil }
        return RemoteImageRequestFactory.boundedRequest(
            url: url,
            maxPixelDimensions: maxPixelDimensions,
            maxPixelWidth: maxPixelWidth
        )
    }
}

/// Non-generic factory so call sites avoid inferring `RemoteImage<Content>`.
public enum RemoteImageRequestFactory {
    /// Builds a request that downscales via Nuke `Resize` (not ImageIO `ThumbnailOptions`).
    ///
    /// ImageIO thumbnails frequently hit `CVPixelBufferCreate … RGBA (-6680)` on simulator/device
    /// and can yield corrupt or mis-sized images (feed media rendering as a thin vertical strip).
    ///
    /// Animated GIF/WebP URLs still get `Resize` when a max size is provided — `RemoteImage` only
    /// needs a still. Full-frame animation belongs in `AnimatedRemoteImage` (`loadData` + ImageIO).
    public static func boundedRequest(
        url: URL,
        maxPixelDimensions: CGSize? = nil,
        maxPixelWidth: CGFloat? = nil
    ) -> ImageRequest {
        guard let maxPixelSize = resolvedMaxPixelSize(
            maxPixelDimensions: maxPixelDimensions,
            maxPixelWidth: maxPixelWidth
        ) else {
            return ImageRequest(url: url)
        }
        return ImageRequest(
            url: url,
            processors: [
                ImageProcessors.Resize(
                    size: CGSize(width: maxPixelSize, height: maxPixelSize),
                    unit: .pixels,
                    contentMode: .aspectFit
                )
            ]
        )
    }

    private static func resolvedMaxPixelSize(
        maxPixelDimensions: CGSize?,
        maxPixelWidth: CGFloat?
    ) -> CGFloat? {
        if let maxPixelDimensions, maxPixelDimensions.width > 0, maxPixelDimensions.height > 0 {
            return max(maxPixelDimensions.width, maxPixelDimensions.height)
        }
        if let maxPixelWidth, maxPixelWidth > 0 {
            return maxPixelWidth
        }
        return nil
    }
}

public enum RemoteImageMetrics {
    /// Max decode longest-edge for full-width feed media.
    public static var feedMediaMaxPixelWidth: CGFloat {
        FeedMediaLayout.feedMediaMaxDecodePixelSize()
    }

    /// Max decode longest-edge for feed media.
    public static var feedMediaMaxPixelSize: CGSize {
        let side = FeedMediaLayout.feedMediaMaxDecodePixelSize()
        return CGSize(width: side, height: side)
    }

    /// Max decode width for a square avatar at the given point size.
    public static func avatarMaxPixelWidth(pointSize: CGFloat) -> CGFloat {
        pointSize * UIScreen.main.scale
    }

    /// Max decode width for inline attachments capped at a point width.
    public static func inlineAttachmentMaxPixelWidth(pointWidth: CGFloat) -> CGFloat {
        pointWidth * UIScreen.main.scale
    }
}
