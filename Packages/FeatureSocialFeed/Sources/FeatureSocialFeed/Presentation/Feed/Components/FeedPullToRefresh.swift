import SwiftUI
import DesignSystem

enum FeedScrollAnchor {
    static let top = "feedTop"
}

// MARK: - Phase

private enum FeedPullRefreshPhase: Equatable {
    case idle
    case pulling
    case loading
}

// MARK: - Preference (iOS 16–17)

private struct FeedPullMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Layout

/// Custom pull-to-refresh: spinner follows pull (rotation ∝ distance); API on release;
/// loading slot stays visible until response; then scrolls to top.
struct FeedPullToRefreshScrollView<Content: View>: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Bool
    @ViewBuilder var content: () -> Content

    private let triggerDistance: CGFloat = 72
    private let loadingSlotHeight: CGFloat = 52
    private let maxPullDistance: CGFloat = 120
    private let pullCooldown: TimeInterval = 0.45

    @State private var phase: FeedPullRefreshPhase = .idle
    @State private var peakPull: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @State private var dragRotation: Double = 0
    @State private var releaseHandled = false
    @State private var restScrollOffset: CGFloat?
    @State private var restMinY: CGFloat?
    @State private var scrollPull: CGFloat = 0
    @State private var minYPull: CGFloat = 0
    @State private var refreshGeneration = 0
    @State private var refreshTask: Task<Void, Never>?
    @State private var ignoresPullUntil = Date.distantPast
    @State private var lastScrollOffset: CGFloat = 0

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    pullMinYTracker

                    refreshHeader
                        .frame(height: headerHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .id(FeedScrollAnchor.top)

                    content()
                }
            }
            .coordinateSpace(name: "feedPullScroll")
            .applyFeedScrollOffsetTracking { offsetY in
                applyPullFromScrollOffset(offsetY, scrollProxy: scrollProxy)
            }
            .onPreferenceChange(FeedPullMinYKey.self) { minY in
                applyPullFromMinY(minY, scrollProxy: scrollProxy)
            }
            .applyFeedScrollBounceAlways()
            .applyFeedScrollPhaseRelease {
                handleScrollRelease(scrollProxy: scrollProxy)
            }
            .onChange(of: isRefreshing) { refreshing in
                if !refreshing {
                    finishRefreshUI(animated: true)
                }
            }
        }
    }

    private var pullMinYTracker: some View {
        Color.clear
            .frame(height: 0)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: FeedPullMinYKey.self,
                        value: geo.frame(in: .named("feedPullScroll")).minY
                    )
                }
            }
    }

    /// Same ring as `LoadingView` / shell — continuous spin while loading or past pull threshold.
    private var refreshHeader: some View {
        let readyToRefresh = peakPull >= triggerDistance
        let spinContinuously = phase == .loading || readyToRefresh

        return ZStack {
            SplickSpinner(
                size: .large,
                rotation: spinContinuously ? 0 : dragRotation,
                isAnimating: spinContinuously
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(phase == .idle && headerHeight < 4 ? 0 : 1)
    }

    // MARK: - Pull distance

    private func applyPullFromScrollOffset(_ offsetY: CGFloat, scrollProxy: ScrollViewProxy) {
        lastScrollOffset = offsetY

        if restScrollOffset == nil {
            restScrollOffset = offsetY
        }
        // Only overscroll past the top counts — scrolling down must not register as pull.
        let overscroll = (restScrollOffset ?? offsetY) - offsetY
        scrollPull = max(0, overscroll)

        if overscroll < 1, offsetY <= (restScrollOffset ?? offsetY) + 2 {
            restScrollOffset = offsetY
        }
        syncCombinedPull(scrollProxy: scrollProxy)
    }

    private func applyPullFromMinY(_ minY: CGFloat, scrollProxy: ScrollViewProxy) {
        // Re-anchor only while the feed top anchor is on screen; avoids false pull after scrolling back up.
        let topAnchorVisible = minY > -48
        if topAnchorVisible {
            if restMinY == nil {
                restMinY = minY
            }
            minYPull = max(0, minY - (restMinY ?? minY))
            if minYPull < 1 {
                restMinY = minY
            }
        } else {
            minYPull = 0
            restMinY = nil
        }
        syncCombinedPull(scrollProxy: scrollProxy)
    }

    /// Pull-to-refresh only when the list is at (or bouncing above) the top.
    private var isScrolledToTop: Bool {
        lastScrollOffset <= 12
    }

    private func syncCombinedPull(scrollProxy: ScrollViewProxy) {
        updatePull(max(scrollPull, minYPull), scrollProxy: scrollProxy)
    }

    private func updatePull(_ pull: CGFloat, scrollProxy: ScrollViewProxy) {
        guard phase != .loading else { return }
        guard Date() >= ignoresPullUntil else { return }
        guard isScrolledToTop else {
            if phase != .idle {
                resetPullState(animated: true)
            }
            return
        }

        let clampedPull = min(pull, maxPullDistance)

        if clampedPull > 0.5 {
            releaseHandled = false
            phase = .pulling
            peakPull = max(peakPull, clampedPull)
            headerHeight = clampedPull
            dragRotation = Double(clampedPull / triggerDistance) * 360
        } else if phase == .pulling {
            // iOS 16–17: no `onScrollPhaseChange` — finger release appears as pull collapse at top.
            if #unavailable(iOS 18.0), !releaseHandled, peakPull >= triggerDistance {
                releaseHandled = true
                beginLoading(scrollProxy: scrollProxy)
                return
            }
            resetPullState(animated: true)
        }
    }

    private func handleScrollRelease(scrollProxy: ScrollViewProxy) {
        guard phase == .pulling, !releaseHandled else { return }
        guard Date() >= ignoresPullUntil else { return }
        guard isScrolledToTop else {
            resetPullState(animated: true)
            return
        }
        releaseHandled = true

        if peakPull >= triggerDistance {
            beginLoading(scrollProxy: scrollProxy)
        } else {
            resetPullState(animated: true)
        }
    }

    private func beginLoading(scrollProxy: ScrollViewProxy) {
        guard isScrolledToTop, peakPull >= triggerDistance else {
            resetPullState(animated: true)
            return
        }
        refreshGeneration += 1
        let generation = refreshGeneration
        refreshTask?.cancel()

        phase = .loading
        peakPull = 0
        scrollPull = 0
        minYPull = 0
        dragRotation = 0

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            headerHeight = loadingSlotHeight
        }

        refreshTask = Task { @MainActor in
            let succeeded = await onRefresh()

            guard generation == refreshGeneration else { return }
            refreshTask = nil

            finishRefreshUI(animated: true)

            // Scroll to top only after an explicit pull-to-refresh (not on accidental triggers).
            if succeeded {
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeOut(duration: 0.28)) {
                    scrollProxy.scrollTo(FeedScrollAnchor.top, anchor: .top)
                }
            }
        }
    }

    private func finishRefreshUI(animated: Bool) {
        ignoresPullUntil = Date().addingTimeInterval(pullCooldown)
        releaseHandled = true
        peakPull = 0
        scrollPull = 0
        minYPull = 0
        dragRotation = 0
        restScrollOffset = nil
        restMinY = nil

        if animated {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                phase = .idle
                headerHeight = 0
            }
        } else {
            phase = .idle
            headerHeight = 0
        }
    }

    private func resetPullState(animated: Bool) {
        phase = .idle
        peakPull = 0
        dragRotation = 0
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                headerHeight = 0
            }
        } else {
            headerHeight = 0
        }
    }
}

// MARK: - Scroll tracking

private extension View {
    @ViewBuilder
    func applyFeedScrollOffsetTracking(onChange: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offsetY in
                onChange(offsetY)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyFeedScrollPhaseRelease(onRelease: @escaping () -> Void) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollPhaseChange { oldPhase, newPhase in
                if oldPhase == .interacting, newPhase != .interacting {
                    onRelease()
                }
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyFeedScrollBounceAlways() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.always, axes: .vertical)
        } else {
            self
        }
    }
}
