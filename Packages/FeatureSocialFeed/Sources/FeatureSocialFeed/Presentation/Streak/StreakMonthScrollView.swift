import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

private enum StreakScrollAnchor {
    static let top = "streakScrollTop"
    static let bottom = "streakScrollBottom"
}

/// Continuous vertical month list.
/// Current month is at the top; pull down to reload, older months load below.
struct StreakMonthScrollView<Header: View>: View {
    @EnvironmentObject private var languageService: LanguageService
    /// True only while the Chuỗi pager page is the active segment.
    @Environment(\.scrollChromeTrackingEnabled) private var isStreakSegmentActive

    let sections: [StreakMonthSection]
    let anchorMonthID: String
    let scrollToEndToken: Int
    let isLoadingOlder: Bool
    let hasReachedOldestMonth: Bool
    let canLoadOlder: Bool
    let onLoadOlder: (StreakMonthSection) async -> Bool
    let onDayTap: (StreakDay) -> Void
    let onRefresh: () async -> Void
    @ViewBuilder var header: () -> Header

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @State private var refreshController = SplickRefreshController()
    @State private var didPinToStart = false
    @State private var isOlderLoadInFlight = false
    @State private var lastOlderLoadTriggerSectionID: String?
    @State private var trackedSectionCount = 0
    @State private var lastScrollToEndToken = -1
    @State private var pinGeneration = 0
    @StateObject private var scrollHost = StreakScrollHost()

    var body: some View {
        VStack(spacing: 0) {
            header()
                .frame(maxWidth: .infinity)
                .padding(.top, SplickSegmentPagerTopInsetMetrics.underChromeTopGap)
                .background {
                    LinearGradient(
                        stops: [
                            .init(color: SplickTheme.Colors.background.opacity(0.98), location: 0),
                            .init(color: SplickTheme.Colors.background.opacity(0.92), location: 0.42),
                            .init(color: SplickTheme.Colors.background.opacity(0.55), location: 0.78),
                            .init(color: SplickTheme.Colors.background.opacity(0.12), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .compositingGroup()
                .zIndex(10)

            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear
                        .frame(height: 0)
                        .id(StreakScrollAnchor.top)

                    LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                        ForEach(sections) { section in
                            StreakMonthSectionView(section: section, onDayTap: onDayTap)
                                .id(section.id)
                                .onAppear {
                                    requestOlderMonthIfNeeded(for: section)
                                }
                        }

                        if isLoadingOlder || isOlderLoadInFlight {
                            SplickSpinner()
                                .padding(.vertical, SplickTheme.Spacing.sm)
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel(languageService.text(.feedStreakLoading))
                        }

                        if hasReachedOldestMonth, !isLoadingOlder, !isOlderLoadInFlight {
                            Text(languageService.text(.feedStreakEndOfHistory))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SplickTheme.Spacing.sm)
                        }
                    }
                    .padding(.top, SplickTheme.Spacing.sm)
                    .padding(.bottom, SplickTheme.Spacing.xl)

                    Color.clear
                        .frame(height: 1)
                        .id(StreakScrollAnchor.bottom)
                }
                .scrollContentBackground(.hidden)
                .background {
                    StreakScrollViewAnchor(host: scrollHost)
                }
                .feedPagerScrollInsets(style: .tight)
                .feedScrollSoftTopEdge()
                .feedScrollBounceAlways()
                .modifier(StreakScrollTopEdgeClear())
                .scrollChromeTracking()
                .splickNativeRefreshable(
                    controller: refreshController,
                    chromeTopInset: FeedPagerTopInsetMetrics.refreshChromeTopInset,
                    heldPullDistance: 44,
                    spinnerTopPadding: SplickTheme.Spacing.xs
                ) {
                    let started = Date()
                    await onRefresh()
                    let remaining = 0.42 - Date().timeIntervalSince(started)
                    if remaining > 0.02 {
                        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    }
                }
                .splickSameTabTapBehavior(
                    scrollTopID: StreakScrollAnchor.top,
                    scrollProxy: proxy,
                    refreshController: refreshController,
                    isAtTop: { tabBarScrollState?.isAtTop ?? true }
                )
                .onAppear {
                    trackedSectionCount = sections.count
                    schedulePinToStartIfNeeded(using: proxy)
                }
                .onChange(of: isStreakSegmentActive) { active in
                    guard active else { return }
                    didPinToStart = false
                    schedulePinToStartIfNeeded(using: proxy)
                }
                .onChange(of: scrollToEndToken) { token in
                    guard token != lastScrollToEndToken else { return }
                    lastScrollToEndToken = token
                    resetPaginationGates()
                    trackedSectionCount = sections.count
                    schedulePinToStartIfNeeded(using: proxy)
                }
                .onChange(of: sections.count) { newCount in
                    let oldCount = trackedSectionCount
                    trackedSectionCount = newCount
                    handleSectionCountChange(oldCount: oldCount, newCount: newCount, proxy: proxy)
                }
                .onChange(of: scrollHost.isNearBottom) { nearBottom in
                    guard nearBottom, didPinToStart, let oldest = sections.last else { return }
                    requestOlderMonthIfNeeded(for: oldest)
                }
            }
        }
    }

    private func resetPaginationGates() {
        didPinToStart = false
        isOlderLoadInFlight = false
        lastOlderLoadTriggerSectionID = nil
    }

    private func schedulePinToStartIfNeeded(using proxy: ScrollViewProxy) {
        guard isStreakSegmentActive else { return }
        guard !sections.isEmpty else { return }

        pinGeneration += 1
        let generation = pinGeneration
        didPinToStart = false

        for delayMs in [0, 16, 50, 120, 250, 450] as [Int] {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                guard generation == pinGeneration else { return }
                guard isStreakSegmentActive else { return }

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(StreakScrollAnchor.top, anchor: .top)
                }
                _ = scrollHost.scrollToTop()

                if delayMs >= 120 {
                    didPinToStart = true
                }
            }
        }
    }

    private func requestOlderMonthIfNeeded(for section: StreakMonthSection) {
        guard didPinToStart else { return }
        guard canLoadOlder, !hasReachedOldestMonth else { return }
        guard section.id == sections.last?.id else { return }
        guard lastOlderLoadTriggerSectionID != section.id else { return }
        guard !isOlderLoadInFlight, !isLoadingOlder else { return }

        lastOlderLoadTriggerSectionID = section.id
        isOlderLoadInFlight = true

        Task {
            _ = await onLoadOlder(section)
            isOlderLoadInFlight = false
        }
    }

    private func handleSectionCountChange(
        oldCount: Int,
        newCount: Int,
        proxy: ScrollViewProxy
    ) {
        if newCount < oldCount {
            resetPaginationGates()
            schedulePinToStartIfNeeded(using: proxy)
            return
        }

        guard newCount > oldCount else { return }
        lastOlderLoadTriggerSectionID = nil
        if scrollHost.isNearBottom, let oldest = sections.last {
            requestOlderMonthIfNeeded(for: oldest)
        }
    }
}

private struct StreakScrollTopEdgeClear: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .top)
        } else {
            content
        }
    }
}

// MARK: - UIScrollView bridge

@MainActor
private final class StreakScrollHost: ObservableObject {
    weak var scrollView: UIScrollView?
    @Published private(set) var isNearBottom = false

    private var offsetObservation: NSKeyValueObservation?
    private var contentSizeObservation: NSKeyValueObservation?
    private let nearBottomThreshold: CGFloat = 180

    func attach(from view: UIView) {
        guard let found = Self.findVerticalScrollView(near: view) else { return }
        guard scrollView !== found else {
            evaluateNearBottom(in: found)
            return
        }
        scrollView = found
        startObserving(found)
        evaluateNearBottom(in: found)
    }

    @discardableResult
    func scrollToTop() -> Bool {
        guard let scrollView else { return false }
        scrollView.layoutIfNeeded()
        let minY = -scrollView.adjustedContentInset.top
        UIView.performWithoutAnimation {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: minY), animated: false)
        }
        evaluateNearBottom(in: scrollView)
        return abs(scrollView.contentOffset.y - minY) < 1.5
    }

    private func startObserving(_ scrollView: UIScrollView) {
        offsetObservation?.invalidate()
        contentSizeObservation?.invalidate()

        offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            Task { @MainActor [weak self] in
                self?.evaluateNearBottom(in: scrollView)
            }
        }
        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] scrollView, _ in
            Task { @MainActor [weak self] in
                self?.evaluateNearBottom(in: scrollView)
            }
        }
    }

    private func evaluateNearBottom(in scrollView: UIScrollView) {
        let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height
            - scrollView.adjustedContentInset.bottom
        let distanceFromBottom = scrollView.contentSize.height - visibleBottom
        let nearBottom = distanceFromBottom <= nearBottomThreshold
        if isNearBottom != nearBottom {
            isNearBottom = nearBottom
        }
    }

    private static func findVerticalScrollView(near view: UIView) -> UIScrollView? {
        var candidates: [UIScrollView] = []

        func consider(_ scrollView: UIScrollView) {
            if scrollView.isPagingEnabled {
                let wide = scrollView.contentSize.width > scrollView.bounds.width * 1.2
                if wide { return }
            }
            let tall = scrollView.contentSize.height >= scrollView.bounds.height * 0.5
                || scrollView.bounds.height > 0
            guard tall else { return }
            if !candidates.contains(where: { $0 === scrollView }) {
                candidates.append(scrollView)
            }
        }

        var ancestor: UIView? = view
        while let current = ancestor {
            if let scrollView = current as? UIScrollView {
                consider(scrollView)
            }
            ancestor = current.superview
        }

        var container: UIView? = view.superview
        var depth = 0
        while let current = container, depth < 6 {
            enumerate(current, visit: consider)
            container = current.superview
            depth += 1
        }

        return candidates.first
    }

    private static func enumerate(_ root: UIView, visit: (UIScrollView) -> Void) {
        if let scrollView = root as? UIScrollView {
            visit(scrollView)
        }
        root.subviews.forEach { enumerate($0, visit: visit) }
    }

    deinit {
        offsetObservation?.invalidate()
        contentSizeObservation?.invalidate()
    }
}

private struct StreakScrollViewAnchor: UIViewRepresentable {
    @ObservedObject var host: StreakScrollHost

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            host.attach(from: uiView)
        }
    }
}
