import SwiftUI
import UIKit

// MARK: - Chrome metrics

public enum FeedSegmentChromeMetrics {
    public static let navigationBarHeight: CGFloat = 48
    /// Capsule row: 34pt buttons + vertical chrome padding.
    public static let segmentRowHeight: CGFloat = 40

    /// Bottom of the inline nav (pills live in the toolbar). Used to pin PTR spinner.
    public static var overlappingNavigationInset: CGFloat {
        let safeTop = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top) ?? 59
        return safeTop + navigationBarHeight
    }
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
        if Thread.isMainThread {
            applyScrollOffset(rawOffset)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyScrollOffset(rawOffset)
            }
        }
    }

    public func snapCollapseProgress() {
        if Thread.isMainThread {
            applySnapCollapseProgress()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applySnapCollapseProgress()
            }
        }
    }

    private func applyScrollOffset(_ rawOffset: CGFloat) {
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
        lastOffset = offset

        if offset <= showAtTopThreshold {
            setCollapseProgress(0)
            return
        }

        // Binary expand/collapse while scrolling — continuous morph rebuilt the
        // principal toolbar every few points and hitching leave-from-top scroll.
        let scrolledPastThreshold = offset - showAtTopThreshold
        let next: CGFloat = scrolledPastThreshold >= collapseDistance * 0.45 ? 1 : 0
        setCollapseProgress(next)
    }

    private func applySnapCollapseProgress() {
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastOffset = 0
            self.lastRawOffset = 0
            self.offsetNormalizer.reset()
            self.setCollapseProgress(0, animated: false)
        }
    }

    private func setCollapseProgress(_ value: CGFloat, animated: Bool = false) {
        let clamped: CGFloat = value >= 0.5 ? 1 : 0
        guard abs(collapseProgress - clamped) > 0.001 else { return }
        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                collapseProgress = clamped
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                collapseProgress = clamped
            }
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
                        guard nearTop || abs(previous - offset) > 1 else { return }
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
                content.scrollChromeUIKitOffsetTracking(
                    isEnabled: scrollChromeTrackingEnabled
                ) { offset in
                    feedSegmentScrollState.updateScrollOffset(offset)
                } onIdle: {
                    feedSegmentScrollState.snapCollapseProgress()
                }
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
                    guard nearTop || abs(previous - offsetY) > 1 else { return }
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
            content.scrollChromeUIKitOffsetTracking(
                isEnabled: scrollChromeTrackingEnabled
            ) { offsetY in
                if pullToRefreshActive {
                    let nearTop = offsetY <= SplickTabBarMetrics.showNearTopThreshold
                    if nearTop {
                        feedSegmentScrollState?.updateScrollOffset(offsetY)
                    }
                    return
                }
                feedSegmentScrollState?.updateScrollOffset(offsetY)
                tabBarScrollState?.updateScrollOffset(offsetY)
            } onIdle: {
                if !pullToRefreshActive {
                    feedSegmentScrollState?.snapCollapseProgress()
                }
            }
        }
    }
}
