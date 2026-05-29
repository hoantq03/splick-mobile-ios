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

    @State private var phase: FeedPullRefreshPhase = .idle
    @State private var peakPull: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @State private var dragRotation: Double = 0
    @State private var releaseHandled = false
    @State private var restScrollOffset: CGFloat?
    @State private var restMinY: CGFloat?
    @State private var scrollPull: CGFloat = 0
    @State private var minYPull: CGFloat = 0

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

    private var refreshHeader: some View {
        ZStack {
            SplickSpinner(
                size: .medium,
                rotation: dragRotation,
                isAnimating: phase == .loading
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(phase == .idle && headerHeight < 4 ? 0 : 1)
    }

  // MARK: - Pull distance

    private func applyPullFromScrollOffset(_ offsetY: CGFloat, scrollProxy: ScrollViewProxy) {
        if restScrollOffset == nil {
            restScrollOffset = offsetY
        }
        let delta = (restScrollOffset ?? offsetY) - offsetY
        scrollPull = max(0, max(delta, -delta))
        if scrollPull < 1, abs(offsetY - (restScrollOffset ?? offsetY)) < 2 {
            restScrollOffset = offsetY
        }
        syncCombinedPull(scrollProxy: scrollProxy)
    }

    private func applyPullFromMinY(_ minY: CGFloat, scrollProxy: ScrollViewProxy) {
        if restMinY == nil {
            restMinY = minY
        }
        minYPull = max(0, minY - (restMinY ?? minY))
        if minYPull < 1 {
            restMinY = minY
        }
        syncCombinedPull(scrollProxy: scrollProxy)
    }

    private func syncCombinedPull(scrollProxy: ScrollViewProxy) {
        updatePull(max(scrollPull, minYPull), scrollProxy: scrollProxy)
    }

    private func updatePull(_ pull: CGFloat, scrollProxy: ScrollViewProxy) {
        guard phase != .loading else { return }

        let clampedPull = min(pull, maxPullDistance)

        if clampedPull > 0.5 {
            releaseHandled = false
            phase = .pulling
            peakPull = max(peakPull, clampedPull)
            headerHeight = clampedPull
            dragRotation = Double(clampedPull / triggerDistance) * 360
        } else if phase == .pulling {
            if !releaseHandled, peakPull >= triggerDistance {
                releaseHandled = true
                beginLoading(scrollProxy: scrollProxy)
                return
            }
            resetPullState(animated: true)
        }
    }

    private func handleScrollRelease(scrollProxy: ScrollViewProxy) {
        guard phase == .pulling, !releaseHandled else { return }
        releaseHandled = true

        if peakPull >= triggerDistance {
            beginLoading(scrollProxy: scrollProxy)
        } else {
            resetPullState(animated: true)
        }
    }

    private func beginLoading(scrollProxy: ScrollViewProxy) {
        phase = .loading
        peakPull = 0
        scrollPull = 0
        minYPull = 0
        dragRotation = 0

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            headerHeight = loadingSlotHeight
        }

        Task { @MainActor in
            let succeeded = await onRefresh()

            if succeeded {
                withAnimation(.easeOut(duration: 0.28)) {
                    scrollProxy.scrollTo(FeedScrollAnchor.top, anchor: .top)
                }
                restScrollOffset = nil
                restMinY = nil
            }

            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                phase = .idle
                headerHeight = 0
            }
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
