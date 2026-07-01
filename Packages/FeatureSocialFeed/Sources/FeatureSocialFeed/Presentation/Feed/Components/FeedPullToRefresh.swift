import SwiftUI
import DesignSystem

enum FeedScrollAnchor {
    static let top = "feedTop"
}

/// Feed scroll container with native pull-to-refresh and tab-bar scroll coordination.
struct FeedPullToRefreshScrollView<Content: View>: View {
    let onRefresh: () async -> Bool
    @ViewBuilder var content: () -> Content

    @State private var lastScrollOffset: CGFloat = 0
    @State private var refreshController = SplickRefreshController()

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.scrollChromeTrackingEnabled) private var scrollChromeTrackingEnabled
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @Environment(\.feedTabIsActive) private var feedTabIsActive

    private var isScrolledToTop: Bool {
        lastScrollOffset <= 12
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(FeedScrollAnchor.top)

                    content()
                }
            }
            .feedPagerScrollInsets()
            .applyFeedScrollOffsetTracking { offsetY in
                lastScrollOffset = offsetY
                guard !pullToRefreshActive else { return }
                if scrollChromeTrackingEnabled {
                    feedSegmentScrollState?.updateScrollOffset(offsetY)
                    tabBarScrollState?.updateScrollOffset(offsetY)
                }
            }
            .applyFeedScrollBounceAlways()
            .applyFeedScrollPhaseRelease {
                guard !pullToRefreshActive else { return }
                if scrollChromeTrackingEnabled {
                    feedSegmentScrollState?.snapCollapseProgress()
                }
            }
            .splickNativeRefreshable(controller: refreshController) {
                let succeeded = await onRefresh()
                if succeeded {
                    withAnimation(.easeOut(duration: 0.28)) {
                        scrollProxy.scrollTo(FeedScrollAnchor.top, anchor: .top)
                    }
                }
            }
            .splickSameTabTapBehavior(
                scrollTopID: FeedScrollAnchor.top,
                scrollProxy: scrollProxy,
                refreshController: refreshController,
                isAtTop: { isScrolledToTop },
                isEnabled: { feedTabIsActive }
            )
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
