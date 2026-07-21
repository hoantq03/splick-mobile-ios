import SwiftUI
import DesignSystem

enum FeedScrollAnchor {
    static let top = "feedTop"
    static let coordinateSpace = "feedPullScroll"
}

private enum FeedProgrammaticRefreshMetrics {
    static let headerHeight: CGFloat = 52
    static let overshootHeight: CGFloat = 88
}

/// Feed scroll container with native gesture pull-to-refresh and same-tab programmatic reload.
struct FeedPullToRefreshScrollView<Content: View>: View {
    let onRefresh: () async -> Bool
    @ViewBuilder var content: () -> Content

    @StateObject private var refreshHost = SplickScrollRefreshHost()
    @State private var isRefreshing = false
    /// Fallback only when native `UIRefreshControl` cannot be resolved.
    @State private var programmaticHeaderHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        if programmaticHeaderHeight > 0.5 {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(SplickTheme.Colors.primaryGradientStart)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: programmaticHeaderHeight)
                    .clipped()

                    Color.clear
                        .frame(height: 0)
                        .id(FeedScrollAnchor.top)
                        .background {
                            SplickScrollViewRefreshAnchor(host: refreshHost)
                        }

                    content()
                        .scrollChromeOffsetTracking(coordinateSpace: FeedScrollAnchor.coordinateSpace)
                }
            }
            .coordinateSpace(name: FeedScrollAnchor.coordinateSpace)
            .feedPagerScrollInsets()
            .feedScrollSoftTopEdge()
            .scrollChromeTracking()
            .applyFeedScrollBounceAlways()
            .refreshable {
                await performRefresh(scrollProxy: scrollProxy, preferNativeHeader: false)
            }
            .environment(\.pullToRefreshActive, isRefreshing)
            .preference(key: PullToRefreshActivePreferenceKey.self, value: isRefreshing)
            .onReceive(NotificationCenter.default.publisher(for: FeedSameTabNotification.scrollToTop)) { _ in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    scrollProxy.scrollTo(FeedScrollAnchor.top, anchor: .top)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: FeedSameTabNotification.refresh)) { _ in
                Task { await performRefresh(scrollProxy: scrollProxy, preferNativeHeader: true) }
            }
        }
    }

    @MainActor
    private func performRefresh(
        scrollProxy: ScrollViewProxy,
        preferNativeHeader: Bool
    ) async {
        guard !isRefreshing else { return }
        isRefreshing = true

        var usedNative = false
        if preferNativeHeader {
            // Keep content at top so the native UIRefreshControl is visible under chrome.
            scrollProxy.scrollTo(FeedScrollAnchor.top, anchor: .top)
            usedNative = await refreshHost.beginRefreshing()
            if !usedNative {
                await playFallbackPullBounce()
            }
        }

        let succeeded = await onRefresh()

        if preferNativeHeader {
            if usedNative {
                refreshHost.endRefreshing()
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    programmaticHeaderHeight = 0
                }
            }
        }
        isRefreshing = false

        if succeeded {
            withAnimation(.easeOut(duration: 0.18)) {
                scrollProxy.scrollTo(FeedScrollAnchor.top, anchor: .top)
            }
        }
    }

    @MainActor
    private func playFallbackPullBounce() async {
        withAnimation(.easeOut(duration: 0.14)) {
            programmaticHeaderHeight = FeedProgrammaticRefreshMetrics.overshootHeight
        }
        try? await Task.sleep(nanoseconds: 140_000_000)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
            programmaticHeaderHeight = FeedProgrammaticRefreshMetrics.headerHeight
        }
        try? await Task.sleep(nanoseconds: 220_000_000)
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
