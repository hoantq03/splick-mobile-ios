import SwiftUI

enum FeedSegmentChromeMetrics {
    /// Standard inline navigation bar content height.
    static let navigationBarHeight: CGFloat = 44
}

/// Tracks feed scroll offset to drive nav-pill collapse morphing in `FeedNavPills`.
@MainActor
final class FeedSegmentScrollState: ObservableObject {
    @Published private(set) var collapseProgress: CGFloat = 0

    private var lastOffset: CGFloat = 0
    private let collapseDistance: CGFloat = 56
    private let scrollThreshold: CGFloat = 4

    func updateScrollOffset(_ offset: CGFloat) {
        if offset <= scrollThreshold {
            collapseProgress = 0
            lastOffset = offset
            return
        }

        let delta = offset - lastOffset
        if delta > scrollThreshold {
            collapseProgress = min(1, collapseProgress + delta / collapseDistance)
        } else if delta < -scrollThreshold {
            collapseProgress = max(0, collapseProgress + delta / collapseDistance)
        }
        lastOffset = offset
    }

    func snapCollapseProgress() {
        collapseProgress = collapseProgress >= 0.5 ? 1 : 0
    }

    func reset() {
        lastOffset = 0
        collapseProgress = 0
    }
}

private struct FeedSegmentScrollStateKey: EnvironmentKey {
    static let defaultValue: FeedSegmentScrollState? = nil
}

extension EnvironmentValues {
    var feedSegmentScrollState: FeedSegmentScrollState? {
        get { self[FeedSegmentScrollStateKey.self] }
        set { self[FeedSegmentScrollStateKey.self] = newValue }
    }
}
