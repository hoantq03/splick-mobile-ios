import SwiftUI
import DesignSystem

enum FeedScrollChromeFadeMetrics {
    static let fadeTail = SplickScrollChromeFadeMetrics.fadeTail

    static func totalHeight(safeTop: CGFloat) -> CGFloat {
        SplickScrollChromeFadeMetrics.totalHeight(safeTop: safeTop)
    }

    static var backgroundStops: [Gradient.Stop] {
        SplickScrollChromeFadeMetrics.backgroundStops
    }

    static var materialMaskStops: [Gradient.Stop] {
        SplickScrollChromeFadeMetrics.materialMaskStops
    }
}

/// Gradual top fade when pager content scrolls beneath the feed navigation chrome.
typealias FeedScrollTopFadeOverlay = SplickScrollTopFadeOverlay

extension View {
    /// Hides iOS 26's hard scroll-edge band; `FeedScrollTopFadeOverlay` provides the soft dissolve.
    @ViewBuilder
    func feedScrollSoftTopEdge() -> some View {
        splickScrollSoftTopEdge()
    }
}
