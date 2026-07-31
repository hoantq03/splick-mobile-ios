import SwiftUI
import DesignSystem
import SplickDomain

private enum StreakScrollAnchor {
    static let top = "streakScrollTop"
}

/// Continuous vertical month list (like photo album). Older months prepend at the top;
/// scroll position is preserved so the viewport does not jump while paginating upward.
struct StreakMonthScrollView: View {
    let sections: [StreakMonthSection]
    let anchorMonthID: String
    let isLoadingOlder: Bool
    let canLoadOlder: Bool
    let onLoadOlder: (StreakMonthSection) async -> Bool
    let onDayTap: (StreakDay) -> Void
    let onRefresh: () async -> Void

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @State private var refreshController = SplickRefreshController()
    @State private var didInitialScroll = false
    @State private var scrollAnchorAfterPrepend: String?
    @State private var lastOlderLoadTriggerSectionID: String?
    @State private var suppressLoadForSectionID: String?
    @State private var trackedSectionCount = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(StreakScrollAnchor.top)

                monthStack
            }
            .scrollContentBackground(.hidden)
            .background(SplickTheme.Colors.background)
            .overlay(alignment: .top) {
                if isLoadingOlder {
                    ProgressView()
                        .padding(.top, SplickTheme.Spacing.sm)
                        .allowsHitTesting(false)
                }
            }
            .feedScrollSoftTopEdge()
            .scrollChromeTracking()
            .splickNativeRefreshable(controller: refreshController) {
                await onRefresh()
            }
            .splickSameTabTapBehavior(
                scrollTopID: StreakScrollAnchor.top,
                scrollProxy: proxy,
                refreshController: refreshController,
                isAtTop: { tabBarScrollState?.isAtTop == true }
            )
            .onAppear {
                trackedSectionCount = sections.count
                scrollToCurrentMonth(using: proxy, animated: false)
            }
            .onChange(of: sections.count) { newCount in
                let oldCount = trackedSectionCount
                trackedSectionCount = newCount
                handleSectionCountChange(
                    oldCount: oldCount,
                    newCount: newCount,
                    proxy: proxy
                )
            }
        }
    }

    private var monthStack: some View {
        LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
            ForEach(sections) { section in
                StreakMonthSectionView(section: section, onDayTap: onDayTap)
                    .id(section.id)
                    .onAppear {
                        requestOlderMonthIfNeeded(for: section)
                    }
                    .onDisappear {
                        if suppressLoadForSectionID == section.id {
                            suppressLoadForSectionID = nil
                        }
                    }
            }
        }
        .padding(.top, SplickTheme.Spacing.xs)
        .padding(.bottom, SplickTheme.Spacing.xl)
    }

    private func requestOlderMonthIfNeeded(for section: StreakMonthSection) {
        guard didInitialScroll else { return }
        guard canLoadOlder else { return }
        guard section.id == sections.first?.id else { return }
        guard suppressLoadForSectionID != section.id else { return }
        guard lastOlderLoadTriggerSectionID != section.id else { return }

        lastOlderLoadTriggerSectionID = section.id

        Task {
            let anchor = section.id
            scrollAnchorAfterPrepend = anchor
            let inserted = await onLoadOlder(section)
            if !inserted {
                scrollAnchorAfterPrepend = nil
            }
        }
    }

    private func handleSectionCountChange(
        oldCount: Int,
        newCount: Int,
        proxy: ScrollViewProxy
    ) {
        if newCount < oldCount {
            lastOlderLoadTriggerSectionID = nil
            scrollAnchorAfterPrepend = nil
            suppressLoadForSectionID = nil
            didInitialScroll = false
            DispatchQueue.main.async {
                scrollToCurrentMonth(using: proxy, animated: false)
            }
            return
        }

        guard newCount > oldCount, let anchor = scrollAnchorAfterPrepend else { return }

        if let newFirstID = sections.first?.id {
            suppressLoadForSectionID = newFirstID
        }

        DispatchQueue.main.async {
            proxy.scrollTo(anchor, anchor: .top)
            scrollAnchorAfterPrepend = nil
        }
    }

    private func scrollToCurrentMonth(using proxy: ScrollViewProxy, animated: Bool) {
        guard !didInitialScroll, !anchorMonthID.isEmpty else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    proxy.scrollTo(anchorMonthID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(anchorMonthID, anchor: .bottom)
            }
            didInitialScroll = true
        }
    }
}
