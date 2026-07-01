import SwiftUI
import UIKit

// Segment order: Streak | Feed | Album  (left → right)
private let feedSegmentOrder: [FeedContentSegment] = [.streak, .feed, .album]

// MARK: - Shared tracking state

private final class _PagerState: ObservableObject {
    @Published var dragOffset: CGFloat = 0
    @Published var currentIndex: Int = 1

    var onIndexChanged: ((Int) -> Void)?

    func drag(to offset: CGFloat) {
        dragOffset = offset
    }

    /// Settles to `targetIndex` with a spring that feels proportional to the
    /// remaining travel distance — small bounce when nearly there, bigger when far.
    ///
    /// Key trick: we rewrite `(currentIndex, dragOffset)` to an equivalent pair
    /// `(targetIndex, adjustedOffset)` that produces the SAME visual position,
    /// then spring `adjustedOffset → 0`.  No visual jump, ever.
    func settle(to targetIndex: Int, pageWidth: CGFloat) {
        // adjustedOffset = visual distance the new "current" page is away from center.
        // Formula preserves continuity: (idx - old) * w + dragOffset = (idx - new) * w + newOffset
        // ⟹ newOffset = (new - old) * w + dragOffset   (evaluated at idx = targetIndex → 0 + …)
        let adjusted = CGFloat(targetIndex - currentIndex) * pageWidth + dragOffset

        // Instant, no animation — visual position unchanged.
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            currentIndex = targetIndex
            dragOffset   = adjusted
        }

        // Spring the remaining gap to 0.
        // fraction ∈ [0,1]: 0 = released right at destination (tiny spring),
        //                    1 = snapped back from far away (bigger spring).
        let fraction  = min(1, abs(adjusted) / max(pageWidth, 1))
        let damping   = 0.92 - 0.18 * fraction   // 0.92 → 0.74 — subtler bounce
        let response  = 0.24 + 0.08 * fraction   // 0.24 → 0.32

        withAnimation(.spring(response: response, dampingFraction: damping)) {
            dragOffset = 0
        }

        onIndexChanged?(targetIndex)
    }

    func jump(to index: Int) {
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            dragOffset   = 0
            currentIndex = index
        }
    }
}

// MARK: - Pages view (inside UIHostingController)

private struct _PagerPagesView<Feed: View, Album: View, Streak: View>: View {
    @ObservedObject var state: _PagerState
    let width: CGFloat
    let height: CGFloat
    let feed: () -> Feed
    let album: () -> Album
    let streak: () -> Streak

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0 ..< feedSegmentOrder.count, id: \.self) { idx in
                pageView(at: idx)
                    .frame(width: width, height: height)
                    .offset(x: CGFloat(idx - state.currentIndex) * width + state.dragOffset)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    @ViewBuilder
    private func pageView(at index: Int) -> some View {
        switch feedSegmentOrder[index] {
        case .streak: streak()
        case .feed:   feed()
        case .album:  album()
        }
    }
}

// MARK: - Public SwiftUI pager

struct FeedContentPager<Feed: View, Album: View, Streak: View>: View {
    @Binding var selection: FeedContentSegment
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var album: () -> Album
    @ViewBuilder var streak: () -> Streak

    var body: some View {
        GeometryReader { proxy in
            let w = max(proxy.size.width, 1)
            let h = proxy.size.height

            _PagerHostRep(
                selection: $selection,
                width: w,
                height: h,
                feed: feed,
                album: album,
                streak: streak
            )
            .frame(width: w, height: h)
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private weak var hostView: UIView?
    private var dragAxis: Axis?
    /// Saved `isScrollEnabled` while a horizontal page swipe is in progress.
    private var scrollLockStates: [(UIScrollView, Bool)] = []

    override init() {
        super.init()
        state.onIndexChanged = { [weak self] idx in
            let segment = feedSegmentOrder[idx]
            self?.onSelectionChanged?(segment)
        }
    }

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
        state.settle(to: target, pageWidth: containerWidth)
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
        guard total > 20 else { return true }
        return abs(velocity.x) * 2 >= abs(velocity.y)
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
        coordinator.onSelectionChanged = { segment in
            selection = segment
        }

        let idx = feedSegmentOrder.firstIndex(of: selection) ?? 1
        if idx != coordinator.state.currentIndex {
            coordinator.state.jump(to: idx)
        }

        viewController.updatePages(
            feed: feed,
            album: album,
            streak: streak,
            width: width,
            height: height
        )
    }
}

// MARK: - Container UIViewController

private final class _PagerContainerVC<Feed: View, Album: View, Streak: View>: UIViewController {
    private let coordinator: _PagerGestureCoordinator
    private var hostingController: UIHostingController<_PagerPagesView<Feed, Album, Streak>>?

    private var currentFeed: () -> Feed
    private var currentAlbum: () -> Album
    private var currentStreak: () -> Streak
    private var currentWidth: CGFloat
    private var currentHeight: CGFloat

    init(
        coordinator: _PagerGestureCoordinator,
        width: CGFloat,
        height: CGFloat,
        feed: @escaping () -> Feed,
        album: @escaping () -> Album,
        streak: @escaping () -> Streak
    ) {
        self.coordinator = coordinator
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

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)

        embedHosting()
    }

    private func embedHosting() {
        let pages = makePagesView()
        let hosting = UIHostingController(rootView: pages)
        hosting.view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            hosting.safeAreaRegions = []
        }

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
        coordinator.attachHostView(view)
    }

    private func makePagesView() -> _PagerPagesView<Feed, Album, Streak> {
        _PagerPagesView(
            state: coordinator.state,
            width: currentWidth,
            height: currentHeight,
            feed: currentFeed,
            album: currentAlbum,
            streak: currentStreak
        )
    }

    func updatePages(
        feed: @escaping () -> Feed,
        album: @escaping () -> Album,
        streak: @escaping () -> Streak,
        width: CGFloat,
        height: CGFloat
    ) {
        let geometryChanged = width != currentWidth || height != currentHeight
        currentFeed = feed
        currentAlbum = album
        currentStreak = streak
        currentWidth = width
        currentHeight = height

        hostingController?.rootView = makePagesView()

        if geometryChanged {
            hostingController?.view.setNeedsLayout()
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        let velocity = pan.velocity(in: view)

        switch pan.state {
        case .began:
            coordinator.handleBegin()
        case .changed:
            coordinator.handleChanged(
                translation: CGPoint(x: translation.x, y: translation.y)
            )
        case .ended, .cancelled:
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
