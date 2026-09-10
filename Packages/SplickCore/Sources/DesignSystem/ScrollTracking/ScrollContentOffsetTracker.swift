import SwiftUI

/// Converts raw `onScrollGeometryChange` offsets into distance scrolled from the initial rest position.
struct ScrollChromeOffsetNormalizer {
    private var baseline: CGFloat?

    mutating func reset() {
        baseline = nil
    }

    mutating func normalize(_ rawOffset: CGFloat) -> CGFloat {
        if baseline == nil {
            baseline = rawOffset
        }
        return max(0, rawOffset - (baseline ?? rawOffset))
    }
}

/// Legacy name kept so call sites that still wrap inner scroll content continue to compile.
/// iOS 18+ is a no-op (geometry observers live on the `ScrollView`); iOS 16–17 uses UIKit KVO.
struct ScrollChromeOffsetTrackingModifier: ViewModifier {
    let coordinateSpace: String

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.scrollChromeTrackingEnabled) private var scrollChromeTrackingEnabled
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
        } else {
            content.scrollChromeUIKitOffsetTracking(
                isEnabled: scrollChromeTrackingEnabled
            ) { offset in
                if pullToRefreshActive {
                    let nearTop = offset <= SplickTabBarMetrics.showNearTopThreshold
                    if nearTop {
                        feedSegmentScrollState?.updateScrollOffset(offset)
                    }
                    return
                }
                tabBarScrollState?.updateScrollOffset(offset)
                feedSegmentScrollState?.updateScrollOffset(offset)
            } onIdle: {
                if !pullToRefreshActive {
                    feedSegmentScrollState?.snapCollapseProgress()
                }
            }
        }
    }
}

extension View {
    /// iOS 16–17 fallback for `.tabBarHideOnScroll()` / `.feedSegmentHideOnScroll()`.
    /// Prefer `.scrollChromeTracking()` on the `ScrollView` itself.
    public func scrollChromeOffsetTracking(coordinateSpace: String) -> some View {
        modifier(ScrollChromeOffsetTrackingModifier(coordinateSpace: coordinateSpace))
    }
}
