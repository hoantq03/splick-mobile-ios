import SwiftUI
import UIKit
import DesignSystem
import Localization
import Common

// Segment order: Streak | Feed | Album  (left → right)
private let feedSegmentOrder: [FeedContentSegment] = [.streak, .feed, .album]

// MARK: - Shared tracking state

private final class _PagerState {
    var dragOffset: CGFloat = 0
    var currentIndex: Int = 1

    func drag(to offset: CGFloat) {
        dragOffset = offset
    }

    func jump(to index: Int) {
        dragOffset = 0
        currentIndex = index
    }
}

private struct _PagerChrome: Equatable {
    var activeSelection: FeedContentSegment
    var feedTabIsActive: Bool
    var sameTabTapHandlingEnabled: Bool
    var pullToRefreshActive: Bool
}

@MainActor
private final class _PagerActivityState: ObservableObject {
    @Published var chrome: _PagerChrome

    init(chrome: _PagerChrome) {
        self.chrome = chrome
    }
}

// MARK: - Public SwiftUI pager

struct FeedContentPager<Feed: View, Album: View, Streak: View>: View {
    @Binding var selection: FeedContentSegment
    var sameTabTapHandlingEnabled: Bool = true
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var album: () -> Album
    @ViewBuilder var streak: () -> Streak

    /// UIHostingController pages don't inherit the outer SwiftUI environment — forward keys explicitly.
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splickVisualTheme) private var splickVisualTheme
    @Environment(\.splickColorTheme) private var splickColorTheme
    @Environment(\.splickBrandPalette) private var splickBrandPalette
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @Environment(\.feedTabIsActive) private var feedTabIsActive

    /// Locale + appearance only. High-frequency flags (tab active, pull-to-refresh, selection)
    /// must not replace UIHostingController roots — that hitch lagged main-tab switches on iOS 17.
    private var contentRevision: Int {
        var hasher = Hasher()
        hasher.combine(languageService.locale)
        hasher.combine(colorScheme == .dark)
        hasher.combine(splickVisualTheme)
        hasher.combine(splickColorTheme)
        return hasher.finalize()
    }

    var body: some View {
        GeometryReader { proxy in
            let w = max(proxy.size.width, 1)
            let h = proxy.size.height

            _PagerHostRep(
                selection: $selection,
                width: w,
                height: h,
                activeSelection: selection,
                contentRevision: contentRevision,
                feedTabIsActive: feedTabIsActive,
                sameTabTapHandlingEnabled: sameTabTapHandlingEnabled,
                pullToRefreshActive: pullToRefreshActive,
                tabBarVisible: tabBarScrollState?.isVisible ?? true,
                feed: {
                    feed().modifier(pagerEnvironment)
                },
                album: {
                    album().modifier(pagerEnvironment)
                },
                streak: {
                    streak().modifier(pagerEnvironment)
                }
            )
            .frame(width: w, height: h)
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pagerEnvironment: _PagerEnvironmentForwarding {
        _PagerEnvironmentForwarding(
            languageService: languageService,
            colorScheme: colorScheme,
            splickVisualTheme: splickVisualTheme,
            splickColorTheme: splickColorTheme,
            splickBrandPalette: splickBrandPalette,
            tabBarScrollState: tabBarScrollState,
            feedSegmentScrollState: feedSegmentScrollState
        )
    }
}

/// Re-applies environment values lost when embedding pages in `UIHostingController`.
/// Tab/refresh flags live on `_PagerActivityState` so they update without remounting pages.
private struct _PagerEnvironmentForwarding: ViewModifier {
    let languageService: LanguageService
    let colorScheme: ColorScheme
    let splickVisualTheme: SplickVisualTheme?
    let splickColorTheme: SplickColorTheme
    let splickBrandPalette: SplickBrandPalette
    let tabBarScrollState: TabBarScrollState?
    let feedSegmentScrollState: FeedSegmentScrollState?

    func body(content: Content) -> some View {
        content
            .environmentObject(languageService)
            .environment(\.colorScheme, colorScheme)
            .environment(\.splickVisualTheme, splickVisualTheme)
            .environment(\.splickColorTheme, splickColorTheme)
            .environment(\.splickBrandPalette, splickBrandPalette)
            .environment(\.tabBarScrollState, tabBarScrollState)
            .environment(\.feedSegmentScrollState, feedSegmentScrollState)
    }
}

// MARK: - Gesture coordinator

private enum _HorizontalPagingHitTest {
    /// Returns true when `view` (or an ancestor) is a horizontally paging scroll surface
    /// such as SwiftUI `TabView(.page)` or `UIPageViewController`'s scroll view.
    static func containsHorizontalPagingSurface(from view: UIView) -> Bool {
        var current: UIView? = view
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView,
               isHorizontalPagingScrollView(scrollView) {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    private static func isHorizontalPagingScrollView(_ scrollView: UIScrollView) -> Bool {
        if scrollView.isPagingEnabled { return true }

        let contentWidth = scrollView.contentSize.width
        let contentHeight = scrollView.contentSize.height
        let boundsWidth = max(scrollView.bounds.width, 1)
        let boundsHeight = max(scrollView.bounds.height, 1)

        // Wide, non-vertical scrollers (multi-photo carousels without explicit paging flag).
        let isWideContent = contentWidth > boundsWidth * 1.4
        let isPrimarilyVerticalFeedScroll =
            contentHeight > boundsHeight * 1.05 && contentWidth <= boundsWidth * 1.05

        return isWideContent && !isPrimarilyVerticalFeedScroll
    }

    static func isPagingScrollView(_ scrollView: UIScrollView) -> Bool {
        isHorizontalPagingScrollView(scrollView)
    }
}

private final class _PagerGestureCoordinator: NSObject, UIGestureRecognizerDelegate {
    let state = _PagerState()
    var onSelectionChanged: ((FeedContentSegment) -> Void)?
    var onInteractiveDragChanged: ((CGFloat) -> Void)?
    var onSettled: ((_ targetIndex: Int, _ adjustedOffset: CGFloat, _ response: CGFloat, _ damping: CGFloat) -> Void)?
    /// When the floating tab bar is on-screen, ignore pans in its clearance so taps are not eaten.
    var tabBarIsVisible: () -> Bool = { true }

    private weak var hostView: UIView?
    private var dragAxis: Axis?
    /// Saved `isScrollEnabled` while a horizontal page swipe is in progress.
    private var scrollLockStates: [(UIScrollView, Bool)] = []

    func attachHostView(_ view: UIView) {
        hostView = view
    }

    func handleBegin() {
        dragAxis = nil
        unlockVerticalScrolling()
    }

    func handleChanged(translation: CGPoint) {
        if dragAxis == nil {
            let dx = abs(translation.x)
            let dy = abs(translation.y)
            guard max(dx, dy) > 8 else { return }
            dragAxis = dx > dy ? .horizontal : .vertical
        }

        if dragAxis == .horizontal {
            lockVerticalScrollingIfNeeded()
            let raw = translation.x
            let atLeft = state.currentIndex == 0 && raw > 0
            let atRight = state.currentIndex == feedSegmentOrder.count - 1 && raw < 0
            state.drag(to: (atLeft || atRight) ? raw * 0.20 : raw)
            onInteractiveDragChanged?(state.dragOffset)
        }
    }

    func handleEnded(translation: CGPoint, velocity: CGPoint, containerWidth: CGFloat) {
        let resolvedAxis = dragAxis
        dragAxis = nil
        unlockVerticalScrolling()

        guard resolvedAxis == .horizontal else { return }

        let threshold = containerWidth * 0.30
        var target = state.currentIndex
        if translation.x < -threshold || velocity.x < -350 {
            target = min(state.currentIndex + 1, feedSegmentOrder.count - 1)
        } else if translation.x > threshold || velocity.x > 350 {
            target = max(state.currentIndex - 1, 0)
        }

        let adjustedOffset = CGFloat(target - state.currentIndex) * containerWidth + state.dragOffset
        let fraction = min(1, abs(adjustedOffset) / max(containerWidth, 1))
        let damping = 1.0
        let response = SplickPageSlideMotion.duration

        state.currentIndex = target
        state.dragOffset = 0
        onSettled?(target, adjustedOffset, response, damping)
        onSelectionChanged?(feedSegmentOrder[target])
    }

    private func lockVerticalScrollingIfNeeded() {
        guard scrollLockStates.isEmpty, let hostView else { return }

        func walk(_ view: UIView) {
            if let scrollView = view as? UIScrollView,
               !_HorizontalPagingHitTest.isPagingScrollView(scrollView) {
                scrollLockStates.append((scrollView, scrollView.isScrollEnabled))
                scrollView.isScrollEnabled = false
            }
            view.subviews.forEach(walk)
        }
        walk(hostView)
    }

    private func unlockVerticalScrolling() {
        scrollLockStates.forEach { scrollView, wasEnabled in
            scrollView.isScrollEnabled = wasEnabled
        }
        scrollLockStates = []
    }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let hostView else { return true }
        guard tabBarIsVisible() else { return true }
        let point = touch.location(in: hostView)
        return point.y <= hostView.bounds.height - SplickTabBarMetrics.floatingClearance
    }

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard let pan = recognizer as? UIPanGestureRecognizer,
              let hostView = pan.view else { return true }

        // Let in-post photo carousels / page controllers own horizontal swipes.
        let location = pan.location(in: hostView)
        if let hitView = hostView.hitTest(location, with: nil),
           _HorizontalPagingHitTest.containsHorizontalPagingSurface(from: hitView) {
            return false
        }

        let velocity = pan.velocity(in: hostView)
        let total = abs(velocity.x) + abs(velocity.y)
        if total > 20 {
            return abs(velocity.x) * 2 >= abs(velocity.y)
        }
        // Near-zero velocity: do not steal taps. Allow slow horizontal swipes
        // only once translation already shows a clear sideways intent.
        let translation = pan.translation(in: hostView)
        let tx = abs(translation.x)
        let ty = abs(translation.y)
        guard tx + ty > 8 else { return false }
        return tx * 2 >= ty
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard otherGestureRecognizer is UIPanGestureRecognizer,
              let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
        return _HorizontalPagingHitTest.isPagingScrollView(scrollView)
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        guard other is UIPanGestureRecognizer else { return false }
        if let scrollView = other.view as? UIScrollView,
           _HorizontalPagingHitTest.isPagingScrollView(scrollView) {
            return false
        }
        // Horizontal segment swipe owns the gesture — block vertical scroll pans.
        if dragAxis == .horizontal {
            return false
        }
        return true
    }
}

// MARK: - UIViewControllerRepresentable

private struct _PagerHostRep<Feed: View, Album: View, Streak: View>: UIViewControllerRepresentable {
    @Binding var selection: FeedContentSegment
    let width: CGFloat
    let height: CGFloat
    let activeSelection: FeedContentSegment
    let contentRevision: Int
    let feedTabIsActive: Bool
    let sameTabTapHandlingEnabled: Bool
    let pullToRefreshActive: Bool
    let tabBarVisible: Bool
    let feed: () -> Feed
    let album: () -> Album
    let streak: () -> Streak

    func makeCoordinator() -> _PagerGestureCoordinator {
        _PagerGestureCoordinator()
    }

    func makeUIViewController(context: Context) -> _PagerContainerVC<Feed, Album, Streak> {
        let coordinator = context.coordinator
        coordinator.state.currentIndex = feedSegmentOrder.firstIndex(of: selection) ?? 1

        return _PagerContainerVC(
            coordinator: coordinator,
            width: width,
            height: height,
            chrome: _PagerChrome(
                activeSelection: activeSelection,
                feedTabIsActive: feedTabIsActive,
                sameTabTapHandlingEnabled: sameTabTapHandlingEnabled,
                pullToRefreshActive: pullToRefreshActive
            ),
            feed: feed,
            album: album,
            streak: streak
        )
    }

    func updateUIViewController(
        _ viewController: _PagerContainerVC<Feed, Album, Streak>,
        context: Context
    ) {
        let coordinator = context.coordinator
        coordinator.tabBarIsVisible = { [tabBarVisible] in tabBarVisible }
        coordinator.onSelectionChanged = { segment in
            selection = segment
        }

        let idx = feedSegmentOrder.firstIndex(of: selection) ?? 1
        if idx != coordinator.state.currentIndex {
            viewController.animateTo(idx)
        }

        viewController.updatePages(
            feed: feed,
            album: album,
            streak: streak,
            width: width,
            height: height,
            chrome: _PagerChrome(
                activeSelection: activeSelection,
                feedTabIsActive: feedTabIsActive,
                sameTabTapHandlingEnabled: sameTabTapHandlingEnabled,
                pullToRefreshActive: pullToRefreshActive
            ),
            contentRevision: contentRevision
        )
    }
}

// MARK: - Container UIViewController

private struct _PagerPageRoot<Content: View>: View {
    let segment: FeedContentSegment
    @ObservedObject var activityState: _PagerActivityState
    let content: Content

    var body: some View {
        let chrome = activityState.chrome
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplickBrandAtmosphere())
            .environment(\.scrollChromeTrackingEnabled, chrome.activeSelection == segment)
            .environment(\.feedTabIsActive, chrome.feedTabIsActive && segment == .feed)
            .environment(
                \.sameTabTapHandlingEnabled,
                chrome.sameTabTapHandlingEnabled && chrome.activeSelection == segment
            )
            .environment(\.pullToRefreshActive, chrome.pullToRefreshActive)
    }
}

private final class _PagerContainerVC<Feed: View, Album: View, Streak: View>: UIViewController {
    private let coordinator: _PagerGestureCoordinator
    private let activityState: _PagerActivityState
    private var feedHostingController: UIHostingController<_PagerPageRoot<Feed>>?
    private var albumHostingController: UIHostingController<_PagerPageRoot<Album>>?
    private var streakHostingController: UIHostingController<_PagerPageRoot<Streak>>?

    private var currentFeed: () -> Feed
    private var currentAlbum: () -> Album
    private var currentStreak: () -> Streak
    private var currentWidth: CGFloat
    private var currentHeight: CGFloat
    private var currentContentRevision: Int?
    /// Lazy-mount segment UI; feed (index 1) is mounted on first layout.
    private var mountedSegmentIndices: Set<Int> = []
    private var lastLayoutSize: CGSize = .zero
    private var isDragging = false
    private var isSettling = false

    init(
        coordinator: _PagerGestureCoordinator,
        width: CGFloat,
        height: CGFloat,
        chrome: _PagerChrome,
        feed: @escaping () -> Feed,
        album: @escaping () -> Album,
        streak: @escaping () -> Streak
    ) {
        self.coordinator = coordinator
        self.activityState = _PagerActivityState(chrome: chrome)
        self.currentWidth = width
        self.currentHeight = height
        self.currentFeed = feed
        self.currentAlbum = album
        self.currentStreak = streak
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = false

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)

        bindCoordinatorCallbacks()
        embedHosting()
        prewarmNeighborSegments()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = pagerSize
        guard size != lastLayoutSize else { return }
        lastLayoutSize = size
        applyLayout()
    }

    private func bindCoordinatorCallbacks() {
        coordinator.onInteractiveDragChanged = { [weak self] _ in
            self?.applyLayout()
        }
        coordinator.onSettled = { [weak self] targetIndex, adjustedOffset, response, damping in
            self?.ensureSegmentMounted(at: targetIndex)
            self?.settle(to: targetIndex, adjustedOffset: adjustedOffset, response: response, damping: damping)
        }
    }

    private func embedHosting() {
        coordinator.attachHostView(view)
        let initialIndex = feedSegmentOrder.firstIndex(of: activityState.chrome.activeSelection) ?? 1
        ensureSegmentMounted(at: initialIndex)
        applyLayout()
    }

    private func ensureSegmentMounted(at index: Int) {
        guard feedSegmentOrder.indices.contains(index) else { return }
        guard !mountedSegmentIndices.contains(index) else { return }
        mountedSegmentIndices.insert(index)

        switch feedSegmentOrder[index] {
        case .streak:
            let hosting = UIHostingController(rootView: makeStreakRoot())
            prepareHost(hosting)
            streakHostingController = hosting
        case .feed:
            let hosting = UIHostingController(rootView: makeFeedRoot())
            prepareHost(hosting)
            feedHostingController = hosting
        case .album:
            let hosting = UIHostingController(rootView: makeAlbumRoot())
            prepareHost(hosting)
            albumHostingController = hosting
        }
    }

    private func refreshMountedRoots() {
        // Feed/album need live root updates (language, session, upload state).
        if mountedSegmentIndices.contains(1), let feedHostingController {
            feedHostingController.rootView = makeFeedRoot()
        }
        if mountedSegmentIndices.contains(2), let albumHostingController {
            albumHostingController.rootView = makeAlbumRoot()
        }
        // Streak: keep the first mounted root. Replacing it resets `onFirstAppear` and
        // can restart calendar fetches while ViewModel is still loading. StreakViewModel
        // is a shared ObservedObject so UI still updates without remounting.
    }

    private func prepareHost<Content: View>(_ hosting: UIHostingController<Content>) {
        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false
        hosting.view.clipsToBounds = false
        if #available(iOS 16.4, *) {
            hosting.safeAreaRegions = []
        }

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    private func makeFeedRoot() -> _PagerPageRoot<Feed> {
        _PagerPageRoot(segment: .feed, activityState: activityState, content: currentFeed())
    }

    private func makeAlbumRoot() -> _PagerPageRoot<Album> {
        _PagerPageRoot(segment: .album, activityState: activityState, content: currentAlbum())
    }

    private func makeStreakRoot() -> _PagerPageRoot<Streak> {
        _PagerPageRoot(segment: .streak, activityState: activityState, content: currentStreak())
    }

    private var hostedPageViews: [UIView?] {
        [
            streakHostingController?.view,
            feedHostingController?.view,
            albumHostingController?.view,
        ]
    }

    private var pagerSize: CGSize {
        CGSize(
            width: max(currentWidth, view.bounds.width, 1),
            height: max(currentHeight, view.bounds.height, 1)
        )
    }

    private func applyLayout() {
        guard isViewLoaded else { return }
        let size = pagerSize
        let bounds = CGRect(origin: .zero, size: size)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let translationUnit = size.width
        let drag = coordinator.state.dragOffset
        let index = coordinator.state.currentIndex

        for (pageIndex, pageView) in hostedPageViews.enumerated() {
            guard let pageView else { continue }
            if pageView.bounds.size != size {
                pageView.bounds = bounds
                pageView.center = center
            }
            pageView.transform = CGAffineTransform(
                translationX: CGFloat(pageIndex - index) * translationUnit + drag,
                y: 0
            )
        }
    }

    private func settle(
        to targetIndex: Int,
        adjustedOffset: CGFloat,
        response: CGFloat,
        damping: CGFloat
    ) {
        coordinator.state.currentIndex = targetIndex
        coordinator.state.dragOffset = adjustedOffset
        applyLayout()

        coordinator.state.dragOffset = 0
        isSettling = true
        UIView.animate(
            withDuration: SplickPageSlideMotion.duration,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) { [weak self] in
            self?.applyLayout()
        } completion: { [weak self] _ in
            guard let self else { return }
            self.isSettling = false
            self.prewarmNeighborSegments()
        }
    }

    /// Programmatic segment change (nav pills) — same horizontal slide as a finished swipe.
    func animateTo(_ index: Int) {
        let from = coordinator.state.currentIndex
        guard index != from, feedSegmentOrder.indices.contains(index) else { return }

        let lower = min(from, index)
        let upper = max(from, index)
        for mountedIndex in lower...upper {
            ensureSegmentMounted(at: mountedIndex)
        }

        let width = max(currentWidth, view.bounds.width, 1)
        let adjustedOffset = CGFloat(index - from) * width
        settle(to: index, adjustedOffset: adjustedOffset, response: SplickPageSlideMotion.duration, damping: 1)
    }

    func jump(to index: Int) {
        ensureSegmentMounted(at: index)
        coordinator.state.jump(to: index)
        applyLayout()
    }

    func updatePages(
        feed: @escaping () -> Feed,
        album: @escaping () -> Album,
        streak: @escaping () -> Streak,
        width: CGFloat,
        height: CGFloat,
        chrome: _PagerChrome,
        contentRevision: Int
    ) {
        let geometryChanged = width != currentWidth || height != currentHeight
        currentFeed = feed
        currentAlbum = album
        currentStreak = streak
        currentWidth = width
        currentHeight = height
        if activityState.chrome != chrome {
            // Never publish from `updateUIViewController` — that is a SwiftUI
            // view-update turn and hitch-logs "Publishing changes from within view updates".
            SplickViewUpdate.after { [activityState] in
                MainActor.assumeIsolated {
                    if activityState.chrome != chrome {
                        activityState.chrome = chrome
                    }
                }
            }
        }

        if let index = feedSegmentOrder.firstIndex(of: chrome.activeSelection) {
            ensureSegmentMounted(at: index)
        }
        if currentContentRevision != contentRevision {
            currentContentRevision = contentRevision
            refreshMountedRoots()
        }
        hostedPageViews.forEach { pageView in
            pageView?.backgroundColor = .clear
            pageView?.isOpaque = false
        }

        if geometryChanged {
            lastLayoutSize = pagerSize
            applyLayout()
        }
    }

    private func prewarmNeighborSegments() {
        let current = coordinator.state.currentIndex
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isDragging, !self.isSettling else { return }
            self.ensureSegmentMounted(at: max(current - 1, 0))
            self.ensureSegmentMounted(at: min(current + 1, feedSegmentOrder.count - 1))
            self.applyLayout()
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        let velocity = pan.velocity(in: view)

        switch pan.state {
        case .began:
            isDragging = true
            coordinator.handleBegin()
            let current = coordinator.state.currentIndex
            ensureSegmentMounted(at: max(current - 1, 0))
            ensureSegmentMounted(at: min(current + 1, feedSegmentOrder.count - 1))
            applyLayout()
        case .changed:
            coordinator.handleChanged(
                translation: CGPoint(x: translation.x, y: translation.y)
            )
        case .ended, .cancelled:
            isDragging = false
            coordinator.handleEnded(
                translation: CGPoint(x: translation.x, y: translation.y),
                velocity: CGPoint(x: velocity.x, y: velocity.y),
                containerWidth: view.bounds.width
            )
        default:
            break
        }
    }
}
