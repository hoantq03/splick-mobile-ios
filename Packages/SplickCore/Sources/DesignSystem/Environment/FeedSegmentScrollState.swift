import SwiftUI

// MARK: - Chrome metrics

public enum FeedSegmentChromeMetrics {
    public static let navigationBarHeight: CGFloat = 48
    /// Capsule row: 34pt buttons + vertical chrome padding.
    public static let segmentRowHeight: CGFloat = 40
}

// MARK: - Scroll-driven collapse

@MainActor
public final class FeedSegmentScrollState: ObservableObject {
    /// 0 = pill tabs visible below nav bar; 1 = pills hidden, active label centered under notch.
    @Published public private(set) var collapseProgress: CGFloat = 0

    public var isExpanded: Bool { collapseProgress < 0.5 }

    private var lastOffset: CGFloat = 0
    private var lastRawOffset: CGFloat = 0
    private var offsetNormalizer = ScrollChromeOffsetNormalizer()
    private let showAtTopThreshold: CGFloat = 6
    private let collapseDistance: CGFloat = 38
    /// Idle snap slack: bounce/settle can sit a few points above 0 while visually at top.
    private let atTopSnapSlack: CGFloat = SplickTabBarMetrics.sameTabAtTopThreshold

    public init() {}

    public func updateScrollOffset(_ rawOffset: CGFloat) {
        lastRawOffset = rawOffset
        // Use raw geometry for "at top" so a drifted baseline cannot leave the
        // title collapsed after the list has already settled at offset 0.
        if rawOffset <= showAtTopThreshold {
            offsetNormalizer.reset()
            lastOffset = 0
            setCollapseProgress(0)
            return
        }

        let offset = offsetNormalizer.normalize(rawOffset)

        if offset <= showAtTopThreshold {
            setCollapseProgress(0)
            lastOffset = offset
            return
        }

        let scrolledPastThreshold = offset - showAtTopThreshold
        let next = min(1, scrolledPastThreshold / collapseDistance)
        setCollapseProgress(next)
        lastOffset = offset
    }

    public func snapCollapseProgress() {
        if lastRawOffset <= atTopSnapSlack {
            setCollapseProgress(0, animated: true)
            return
        }
        let progressFromOffset: CGFloat
        if lastOffset <= showAtTopThreshold {
            progressFromOffset = 0
        } else {
            progressFromOffset = min(1, (lastOffset - showAtTopThreshold) / collapseDistance)
        }
        setCollapseProgress(progressFromOffset >= 0.5 ? 1 : 0, animated: true)
    }

    public func reset() {
        lastOffset = 0
        lastRawOffset = 0
        offsetNormalizer.reset()
        setCollapseProgress(0, animated: false)
    }

    private func setCollapseProgress(_ value: CGFloat, animated: Bool = false) {
        let clamped = min(1, max(0, value))
        guard abs(collapseProgress - clamped) > 0.001 else { return }
        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                collapseProgress = clamped
            }
        } else {
            collapseProgress = clamped
        }
    }
}

private struct FeedSegmentScrollStateKey: EnvironmentKey {
    static let defaultValue: FeedSegmentScrollState? = nil
}

extension EnvironmentValues {
    public var feedSegmentScrollState: FeedSegmentScrollState? {
        get { self[FeedSegmentScrollStateKey.self] }
        set { self[FeedSegmentScrollStateKey.self] = newValue }
    }
}

public struct FeedSegmentHideOnScrollModifier: ViewModifier {
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.scrollChromeTrackingEnabled) private var scrollChromeTrackingEnabled

    public init() {}

    public func body(content: Content) -> some View {
        if let feedSegmentScrollState {
            if #available(iOS 18.0, *) {
                content
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { previous, offset in
                        guard scrollChromeTrackingEnabled else { return }
                        let nearTop = offset <= SplickTabBarMetrics.showNearTopThreshold
                        guard nearTop || abs(previous - offset) > 0.25 else { return }
                        feedSegmentScrollState.updateScrollOffset(offset)
                    }
                    .onScrollPhaseChange { _, newPhase, context in
                        guard scrollChromeTrackingEnabled else { return }
                        let offsetY = context.geometry.contentOffset.y + context.geometry.contentInsets.top
                        feedSegmentScrollState.updateScrollOffset(offsetY)
                        if newPhase == .idle {
                            feedSegmentScrollState.snapCollapseProgress()
                        }
                    }
            } else {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    public func feedSegmentHideOnScroll() -> some View {
        modifier(FeedSegmentHideOnScrollModifier())
    }

    /// Single scroll-geometry observer for tab bar hide + feed segment pill collapse (iOS 18+).
    public func scrollChromeTracking() -> some View {
        modifier(ScrollChromeTrackingModifier())
    }
}

/// Preferred modifier when both tab bar and feed nav chrome should react to scroll.
public struct ScrollChromeTrackingModifier: ViewModifier {
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.scrollChromeTrackingEnabled) private var scrollChromeTrackingEnabled
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive

    public init() {}

    public func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { previous, offsetY in
                    guard scrollChromeTrackingEnabled else { return }
                    let nearTop = offsetY <= SplickTabBarMetrics.showNearTopThreshold
                    if pullToRefreshActive {
                        if nearTop {
                            feedSegmentScrollState?.updateScrollOffset(offsetY)
                        }
                        return
                    }
                    guard nearTop || abs(previous - offsetY) > 0.25 else { return }
                    feedSegmentScrollState?.updateScrollOffset(offsetY)
                    tabBarScrollState?.updateScrollOffset(offsetY)
                }
                .onScrollPhaseChange { _, newPhase, context in
                    guard scrollChromeTrackingEnabled else { return }
                    let offsetY = context.geometry.contentOffset.y + context.geometry.contentInsets.top
                    let nearTop = offsetY <= SplickTabBarMetrics.showNearTopThreshold
                    if !pullToRefreshActive || nearTop {
                        feedSegmentScrollState?.updateScrollOffset(offsetY)
                    }
                    if !pullToRefreshActive {
                        tabBarScrollState?.updateScrollOffset(offsetY)
                    }
                    if newPhase == .idle, !pullToRefreshActive {
                        feedSegmentScrollState?.snapCollapseProgress()
                    }
                }
        } else {
            content
        }
    }
}
