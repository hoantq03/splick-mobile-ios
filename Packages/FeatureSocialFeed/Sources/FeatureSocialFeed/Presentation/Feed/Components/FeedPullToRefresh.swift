import SwiftUI
import DesignSystem

enum FeedScrollAnchor {
    static let top = "feedTop"
}

/// Feed scroll container with native pull-to-refresh and tab-bar scroll coordination.
struct FeedPullToRefreshScrollView<Content: View>: View {
    let onRefresh: () async -> Bool
    @ViewBuilder var content: () -> Content

    @State private var refreshController = SplickRefreshController()

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedTabIsActive) private var feedTabIsActive

    private var isScrolledToTop: Bool {
        tabBarScrollState?.isAtTop ?? true
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
            .feedScrollSoftTopEdge()
            .scrollChromeTracking()
            .applyFeedScrollBounceAlways()
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

// MARK: - Scroll helpers

private extension View {
    @ViewBuilder
    func applyFeedScrollBounceAlways() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.always, axes: .vertical)
        } else {
            self
        }
    }
}
