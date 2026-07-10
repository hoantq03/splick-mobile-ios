import SwiftUI
import UIKit
import Nuke
import NukeUI

/// Drop-in replacement for `AsyncImage` backed by Nuke memory + disk cache.
/// Nuke is an implementation detail — feature packages import `DesignSystem` only.
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
        .onDisappear(.cancel)
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
    /// Builds a request that downscales at decode time (ImageIO thumbnail), not after a full-resolution decode.
    public static func boundedRequest(
        url: URL,
        maxPixelDimensions: CGSize? = nil,
        maxPixelWidth: CGFloat? = nil
    ) -> ImageRequest {
        var request = ImageRequest(url: url)
        if let thumbnail = thumbnailOptions(
            maxPixelDimensions: maxPixelDimensions,
            maxPixelWidth: maxPixelWidth
        ) {
            request.thumbnail = thumbnail
        }
        return request
    }

    private static func thumbnailOptions(
        maxPixelDimensions: CGSize?,
        maxPixelWidth: CGFloat?
    ) -> ImageRequest.ThumbnailOptions? {
        let maxPixelSize: Float?
        if let maxPixelDimensions, maxPixelDimensions.width > 0, maxPixelDimensions.height > 0 {
            maxPixelSize = Float(max(maxPixelDimensions.width, maxPixelDimensions.height))
        } else if let maxPixelWidth, maxPixelWidth > 0 {
            maxPixelSize = Float(maxPixelWidth)
        } else {
            maxPixelSize = nil
        }

        guard let maxPixelSize else { return nil }

        var options = ImageRequest.ThumbnailOptions(maxPixelSize: maxPixelSize)
        // ImageIO already rotates pixels when true, but Nuke still applies EXIF on UIImage → upside-down.
        options.createThumbnailWithTransform = false
        return options
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
