import CoreGraphics
import SplickDomain
import UIKit

/// Feed post media layout bounds and height calculation from aspect ratio.
public enum FeedMediaLayout {
    /// Minimum rendered height for feed media cells.
    public static let minHeight: CGFloat = 200
    /// Maximum rendered height — scales with screen so portrait photos can show nearly full frame.
    public static var maxHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return min(screenHeight * 0.72, 720)
    }
    /// Fallback height when aspect ratio is unavailable (legacy posts).
    public static let defaultHeight: CGFloat = 350
    /// Placeholder height while media is loading.
    public static let placeholderHeight: CGFloat = 250

    /// Matches grouped section cards (e.g. bill split block below media).
    public static let cornerRadius: CGFloat = SplickTheme.CornerRadius.card

    /// Max longest-edge pixel size when decoding feed media.
    public static let decodeMaxPixelSide: CGFloat = 768

    /// Estimated card content width (feed list padding + card padding on each side).
    public static var estimatedCardContentWidth: CGFloat {
        let screen = max(UIScreen.main.bounds.width, 320)
        let horizontalInset = (SplickTheme.Spacing.md + SplickTheme.Spacing.md) * 2
        return max(screen - horizontalInset, 240)
    }

    /// Natural height at full container width before clamping.
    public static func naturalHeight(for item: PostMediaItem, containerWidth: CGFloat) -> CGFloat? {
        guard let ratio = item.aspectRatio, containerWidth > 0 else { return nil }
        return containerWidth / ratio
    }

    /// Clamped display height for a media item in the feed.
    public static func displayHeight(for item: PostMediaItem, containerWidth: CGFloat) -> CGFloat {
        guard let natural = naturalHeight(for: item, containerWidth: containerWidth) else {
            return defaultHeight
        }
        return min(max(natural, minHeight), maxHeight)
    }

    /// True when the natural height falls outside min/max and content will be cropped via scale-to-fill.
    public static func isHeightClamped(for item: PostMediaItem, containerWidth: CGFloat) -> Bool {
        guard let natural = naturalHeight(for: item, containerWidth: containerWidth) else { return false }
        return natural < minHeight || natural > maxHeight
    }

    /// Whether media should fill the frame (zoom/crop) vs fit naturally at full width.
    public static func shouldFillFrame(for item: PostMediaItem, containerWidth: CGFloat) -> Bool {
        if item.aspectRatio == nil { return true }
        return isHeightClamped(for: item, containerWidth: containerWidth)
    }

    /// Longest-edge decode cap for a feed media cell — width-bound so portrait photos stay small in memory.
    public static func feedMediaMaxDecodePixelSize(
        containerWidth: CGFloat = estimatedCardContentWidth,
        displayHeight: CGFloat? = nil
    ) -> CGFloat {
        let scale = UIScreen.main.scale
        return min(containerWidth * scale, decodeMaxPixelSide)
    }

    /// Deprecated: 2D boxes can still decode portrait photos at width×height (e.g. 1512×2016).
    public static func feedMediaMaxPixelSize(containerWidth: CGFloat = estimatedCardContentWidth) -> CGSize {
        let maxSide = feedMediaMaxDecodePixelSize(containerWidth: containerWidth)
        return CGSize(width: maxSide, height: maxSide)
    }
}
