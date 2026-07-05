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
        .onDisappear(.lowerPriority)
    }

    private var imageRequest: ImageRequest? {
        guard let url else { return nil }
        if let maxPixelDimensions, maxPixelDimensions.width > 0, maxPixelDimensions.height > 0 {
            return ImageRequest(
                url: url,
                processors: [
                    .resize(
                        size: maxPixelDimensions,
                        unit: .pixels,
                        contentMode: .aspectFit
                    ),
                ]
            )
        }
        if let maxPixelWidth, maxPixelWidth > 0 {
            return ImageRequest(
                url: url,
                processors: [.resize(width: maxPixelWidth, unit: .pixels)]
            )
        }
        return ImageRequest(url: url)
    }
}

public enum RemoteImageMetrics {
    /// Max decode width for full-width feed media (legacy width-only cap).
    public static var feedMediaMaxPixelWidth: CGFloat {
        FeedMediaLayout.feedMediaMaxPixelSize.width
    }

    /// Max decode dimensions for feed media (width + height cap).
    public static var feedMediaMaxPixelSize: CGSize {
        FeedMediaLayout.feedMediaMaxPixelSize
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
