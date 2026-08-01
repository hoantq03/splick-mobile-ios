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
/// - Pins to the current month when the Chuỗi segment becomes visible.
/// - Reaching the oldest visible month auto-loads older history.
/// - When history is exhausted, shows an end label above the oldest month.
struct StreakMonthScrollView: View {
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

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @State private var refreshController = SplickRefreshController()
    @State private var didPinToEnd = false
    @State private var isOlderLoadInFlight = false
    @State private var suppressLoadForSectionID: String?
    @State private var lastOlderLoadTriggerSectionID: String?
    @State private var scrollAnchorAfterPrepend: String?
    @State private var trackedSectionCount = 0
    @State private var lastScrollToEndToken = -1
    @State private var pinGeneration = 0
    @StateObject private var scrollHost = StreakScrollHost()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(StreakScrollAnchor.top)

                LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    if hasReachedOldestMonth, !isLoadingOlder, !isOlderLoadInFlight {
                        Text(languageService.text(.feedStreakEndOfHistory))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SplickTheme.Spacing.sm)
                    }

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

                Color.clear
                    .frame(height: 1)
                    .id(StreakScrollAnchor.bottom)
            }
            .scrollContentBackground(.hidden)
            .background(SplickTheme.Colors.background)
            .background {
                StreakScrollViewAnchor(host: scrollHost)
            }
            .overlay(alignment: .top) {
                if isLoadingOlder || isOlderLoadInFlight {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(SplickTheme.Colors.primaryGradientStart)
                        .padding(.vertical, SplickTheme.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(SplickTheme.Colors.background.opacity(0.92))
                        .accessibilityLabel(languageService.text(.feedStreakLoading))
                        .allowsHitTesting(false)
                }
            }
            .feedScrollSoftTopEdge()
            .scrollChromeTracking()
            .onChange(of: refreshController.requestID) { requestID in
                guard requestID > 0 else { return }
                Task { await onRefresh() }
            }
            .splickSameTabTapBehavior(
                scrollTopID: StreakScrollAnchor.top,
                scrollProxy: proxy,
                refreshController: refreshController,
                isAtTop: { tabBarScrollState?.isAtTop == true }
            )
            .onAppear {
                trackedSectionCount = sections.count
                schedulePinToEndIfNeeded(using: proxy)
            }
            .onChange(of: isStreakSegmentActive) { active in
                guard active else { return }
                // Pager often premounts Chuỗi while still on Tin — pin only once visible.
                didPinToEnd = false
                schedulePinToEndIfNeeded(using: proxy)
            }
            .onChange(of: scrollToEndToken) { token in
                guard token != lastScrollToEndToken else { return }
                lastScrollToEndToken = token
                resetPaginationGates()
                trackedSectionCount = sections.count
                schedulePinToEndIfNeeded(using: proxy)
            }
            .onChange(of: sections.count) { newCount in
                let oldCount = trackedSectionCount
                trackedSectionCount = newCount
                handleSectionCountChange(oldCount: oldCount, newCount: newCount, proxy: proxy)
            }
            .onChange(of: scrollHost.isNearTop) { nearTop in
                guard nearTop, didPinToEnd, let oldest = sections.first else { return }
                requestOlderMonthIfNeeded(for: oldest)
            }
        }
    }

    private func resetPaginationGates() {
        didPinToEnd = false
        isOlderLoadInFlight = false
        suppressLoadForSectionID = nil
        lastOlderLoadTriggerSectionID = nil
        scrollAnchorAfterPrepend = nil
        scrollHost.cancelPendingCapture()
    }

    private func schedulePinToEndIfNeeded(using proxy: ScrollViewProxy) {
        guard isStreakSegmentActive else { return }
        guard !sections.isEmpty else { return }

        pinGeneration += 1
        let generation = pinGeneration
        didPinToEnd = false

        // Retry across layouts — LazyVStack + UIHostingController often ignore the first scrollTo.
        for delayMs in [0, 16, 50, 120, 250, 450] as [Int] {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                guard generation == pinGeneration else { return }
                guard isStreakSegmentActive else { return }

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if !anchorMonthID.isEmpty {
                        proxy.scrollTo(anchorMonthID, anchor: .bottom)
                    }
                    proxy.scrollTo(StreakScrollAnchor.bottom, anchor: .bottom)
                }
                _ = scrollHost.scrollToBottom()

                if delayMs >= 120 {
                    didPinToEnd = true
                    // Only auto-page when pin left us on the oldest edge (short content / failed pin).
                    if scrollHost.isNearTop, let oldest = sections.first {
                        requestOlderMonthIfNeeded(for: oldest)
                    }
                }
            }
        }
    }

    private func requestOlderMonthIfNeeded(for section: StreakMonthSection) {
        guard didPinToEnd else { return }
        guard canLoadOlder, !hasReachedOldestMonth else { return }
        guard section.id == sections.first?.id else { return }
        guard suppressLoadForSectionID != section.id else { return }
        guard lastOlderLoadTriggerSectionID != section.id else { return }
        guard !isOlderLoadInFlight, !isLoadingOlder else { return }

        lastOlderLoadTriggerSectionID = section.id
        isOlderLoadInFlight = true
        scrollAnchorAfterPrepend = section.id
        scrollHost.captureBeforePrepend()

        Task {
            let inserted = await onLoadOlder(section)
            if !inserted {
                scrollAnchorAfterPrepend = nil
                scrollHost.cancelPendingCapture()
            }
            isOlderLoadInFlight = false
            // Continue via sections.onChange / oldest onAppear with fresh section ids.
            // Do not chain against the stale `sections` snapshot captured here.
        }
    }

    private func handleSectionCountChange(
        oldCount: Int,
        newCount: Int,
        proxy: ScrollViewProxy
    ) {
        if newCount < oldCount {
            resetPaginationGates()
            schedulePinToEndIfNeeded(using: proxy)
            return
        }

        guard newCount > oldCount else { return }

        let previousAnchor = scrollAnchorAfterPrepend
        if let newFirstID = sections.first?.id {
            // Suppress one eager onAppear for the just-prepended month unless we are
            // still parked at the top and need to keep filling history.
            suppressLoadForSectionID = scrollHost.isNearTop ? nil : newFirstID
        }

        if let anchor = previousAnchor {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo(anchor, anchor: .top)
            }
            scrollAnchorAfterPrepend = nil
        }
        scrollHost.compensateAfterPrependAcrossLayouts()

        lastOlderLoadTriggerSectionID = nil
        if scrollHost.isNearTop, let oldest = sections.first {
            requestOlderMonthIfNeeded(for: oldest)
        }
    }
}

// MARK: - UIScrollView bridge

@MainActor
private final class StreakScrollHost: ObservableObject {
    weak var scrollView: UIScrollView?
    @Published private(set) var isNearTop = false

    private var capturedContentHeight: CGFloat?
    private var capturedOffsetY: CGFloat?
    private var compensationWorkItem: DispatchWorkItem?
    private var offsetObservation: NSKeyValueObservation?
    private var contentSizeObservation: NSKeyValueObservation?
    private let nearTopThreshold: CGFloat = 140

    func attach(from view: UIView) {
        guard let found = Self.findVerticalScrollView(near: view) else { return }
        guard scrollView !== found else {
            evaluateNearTop(in: found)
            return
        }
        scrollView = found
        startObserving(found)
        evaluateNearTop(in: found)
    }

    @discardableResult
    func scrollToBottom() -> Bool {
        guard let scrollView else { return false }
        scrollView.layoutIfNeeded()
        guard scrollView.bounds.height > 1, scrollView.contentSize.height > 1 else { return false }

        let minY = -scrollView.adjustedContentInset.top
        let maxY = max(
            minY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        UIView.performWithoutAnimation {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: maxY), animated: false)
        }
        evaluateNearTop(in: scrollView)
        return abs(scrollView.contentOffset.y - maxY) < 1.5
    }

    func captureBeforePrepend() {
        compensationWorkItem?.cancel()
        guard let scrollView else {
            capturedContentHeight = nil
            capturedOffsetY = nil
            return
        }
        scrollView.layoutIfNeeded()
        capturedContentHeight = scrollView.contentSize.height
        capturedOffsetY = scrollView.contentOffset.y
    }

    func cancelPendingCapture() {
        compensationWorkItem?.cancel()
        compensationWorkItem = nil
        capturedContentHeight = nil
        capturedOffsetY = nil
    }

    func compensateAfterPrependAcrossLayouts() {
        compensationWorkItem?.cancel()
        var attempts = 0
        let maxAttempts = 8

        func attempt() {
            attempts += 1
            if compensateOnce() || attempts >= maxAttempts {
                compensationWorkItem = nil
                if let scrollView {
                    evaluateNearTop(in: scrollView)
                }
                return
            }
            let work = DispatchWorkItem { attempt() }
            compensationWorkItem = work
            DispatchQueue.main.async(execute: work)
        }

        attempt()
    }

    private func startObserving(_ scrollView: UIScrollView) {
        offsetObservation?.invalidate()
        contentSizeObservation?.invalidate()

        offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            Task { @MainActor [weak self] in
                self?.evaluateNearTop(in: scrollView)
            }
        }
        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] scrollView, _ in
            Task { @MainActor [weak self] in
                self?.evaluateNearTop(in: scrollView)
            }
        }
    }

    private func evaluateNearTop(in scrollView: UIScrollView) {
        let distanceFromTop = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let nearTop = distanceFromTop <= nearTopThreshold
        if isNearTop != nearTop {
            isNearTop = nearTop
        }
    }

    @discardableResult
    private func compensateOnce() -> Bool {
        guard let scrollView,
              let previousHeight = capturedContentHeight,
              let previousOffsetY = capturedOffsetY else {
            return false
        }

        scrollView.layoutIfNeeded()
        let delta = scrollView.contentSize.height - previousHeight
        guard delta > 0.5 else { return false }

        capturedContentHeight = nil
        capturedOffsetY = nil

        var offset = scrollView.contentOffset
        offset.y = previousOffsetY + delta
        let minY = -scrollView.adjustedContentInset.top
        let maxY = max(
            minY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        offset.y = min(max(offset.y, minY), maxY)

        UIView.performWithoutAnimation {
            scrollView.setContentOffset(offset, animated: false)
        }
        return true
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

        // Prefer the innermost vertical scroller (streak list), not a parent container.
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
