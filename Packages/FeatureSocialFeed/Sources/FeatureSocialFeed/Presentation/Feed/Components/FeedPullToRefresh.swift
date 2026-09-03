import SwiftUI
import DesignSystem

enum FeedScrollAnchor {
    static let top = "feedTop"
    static let coordinateSpace = "feedPullScroll"
}

/// Feed scroll container with native gesture pull-to-refresh and same-tab programmatic reload.
struct FeedPullToRefreshScrollView<Content: View>: View {
    let onRefresh: () async -> Bool
    @ViewBuilder var content: () -> Content

    @StateObject private var refreshHost = SplickScrollRefreshHost()
    @State private var isRefreshing = false
    /// Shown as a safeAreaInset spinner when the native UIRefreshControl cannot be resolved.
    @State private var showsFallbackSpinner = false

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(FeedScrollAnchor.top)
                        .background {
                            SplickScrollViewRefreshAnchor(host: refreshHost)
                        }

                    content()
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
            // Fallback spinner slides in from the top as a safe-area inset so it is always
            // visible above the scroll content regardless of the current scroll position.
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsFallbackSpinner {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(SplickTheme.Colors.primaryGradientStart)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: showsFallbackSpinner)
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
            // Snap to top first so the native UIRefreshControl is within the visible area.
            scrollProxy.scrollTo(FeedScrollAnchor.top, anchor: .top)
            // Yield one runloop turn so SwiftUI flushes the scroll before UIKit takes over.
            await Task.yield()
            usedNative = await refreshHost.beginRefreshing()
            if !usedNative {
                await showFallbackSpinner()
            }
        }

        let succeeded = await onRefresh()

        if preferNativeHeader {
            if usedNative {
                // endRefreshing() collapses the spinner and repositions the scroll view
                // via UIKit. Do not call scrollProxy.scrollTo right after — it conflicts
                // with UIKit's own spring-back animation and pushes content too high.
                refreshHost.endRefreshing()
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    showsFallbackSpinner = false
                }
            }
        }
        isRefreshing = false

        // For PTR triggered by the user (preferNativeHeader = false), scroll back to the
        // anchor after the data lands. For programmatic refresh the scroll position is
        // already correct after endRefreshing() / fallback collapse.
        if succeeded, !preferNativeHeader {
            withAnimation(.easeOut(duration: 0.18)) {
                scrollProxy.scrollTo(FeedScrollAnchor.top, anchor: .top)
            }
        }
    }

    @MainActor
    private func showFallbackSpinner() async {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showsFallbackSpinner = true
        }
        // Keep the spinner visible for a brief beat so the user knows a refresh is in flight.
        try? await Task.sleep(for: .milliseconds(300))
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
