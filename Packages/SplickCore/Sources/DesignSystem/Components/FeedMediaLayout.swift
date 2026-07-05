import CoreGraphics
import SplickDomain
import UIKit

/// Feed post media layout bounds and height calculation from aspect ratio.
public enum FeedMediaLayout {
    /// Minimum rendered height for feed media cells.
    public static let minHeight: CGFloat = 200
    /// Maximum rendered height for feed media cells.
    public static let maxHeight: CGFloat = 500
    /// Fallback height when aspect ratio is unavailable (legacy posts).
    public static let defaultHeight: CGFloat = 350
    /// Placeholder height while media is loading.
    public static let placeholderHeight: CGFloat = 250

    /// Max pixel dimension used when decoding feed media (avoids oversized CVPixelBuffers).
    public static let decodeMaxPixelSide: CGFloat = 1280

    public static var containerWidth: CGFloat {
        max(UIScreen.main.bounds.width, 320)
    }

    /// Natural height at full container width before clamping.
    public static func naturalHeight(for item: PostMediaItem, containerWidth: CGFloat = containerWidth) -> CGFloat? {
        guard let ratio = item.aspectRatio else { return nil }
        return containerWidth / ratio
    }

    /// Clamped display height for a media item in the feed.
    public static func displayHeight(for item: PostMediaItem, containerWidth: CGFloat = containerWidth) -> CGFloat {
        guard let natural = naturalHeight(for: item, containerWidth: containerWidth) else {
            return defaultHeight
        }
        return min(max(natural, minHeight), maxHeight)
    }

    /// True when the natural height falls outside min/max and content will be cropped via scale-to-fill.
    public static func isHeightClamped(for item: PostMediaItem, containerWidth: CGFloat = containerWidth) -> Bool {
        guard let natural = naturalHeight(for: item, containerWidth: containerWidth) else { return false }
        return natural < minHeight || natural > maxHeight
    }

    /// Max decode size matching the clamped feed layout (screen width × max height, capped).
    public static var feedMediaMaxPixelSize: CGSize {
        let scale = UIScreen.main.scale
        let width = min(containerWidth * scale, decodeMaxPixelSide)
        let height = min(maxHeight * scale, decodeMaxPixelSide)
        return CGSize(width: width, height: height)
    }
}
