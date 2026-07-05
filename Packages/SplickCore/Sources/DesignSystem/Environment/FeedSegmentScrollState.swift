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
    private var offsetNormalizer = ScrollChromeOffsetNormalizer()
    private let showAtTopThreshold: CGFloat = 6
    private let collapseDistance: CGFloat = 38

    public init() {}

    public func updateScrollOffset(_ rawOffset: CGFloat) {
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
        let target: CGFloat = collapseProgress >= 0.5 ? 1 : 0
        setCollapseProgress(target, animated: true)
    }

    public func reset() {
        lastOffset = 0
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
                        guard abs(previous - offset) > 0.25 else { return }
                        feedSegmentScrollState.updateScrollOffset(offset)
                    }
                    .onScrollPhaseChange { oldPhase, newPhase in
                        if oldPhase == .interacting, newPhase != .interacting {
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
                    guard scrollChromeTrackingEnabled, !pullToRefreshActive else { return }
                    guard abs(previous - offsetY) > 0.25 else { return }
                    feedSegmentScrollState?.updateScrollOffset(offsetY)
                    tabBarScrollState?.updateScrollOffset(offsetY)
                }
                .onScrollPhaseChange { oldPhase, newPhase in
                    if oldPhase == .interacting, newPhase != .interacting {
                        guard scrollChromeTrackingEnabled, !pullToRefreshActive else { return }
                        feedSegmentScrollState?.snapCollapseProgress()
                    }
                }
        } else {
            content
        }
    }
}
