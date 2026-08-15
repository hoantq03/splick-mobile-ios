import SwiftUI
import UIKit
import DesignSystem
import Localization

enum ExpensePagerMotion {
    /// Programmatic page settle — matches FeedContentPager pill taps (UIKit spring).
    static let settleDuration: TimeInterval = 0.22
    static let settleDamping: CGFloat = 0.92
    /// Pill indicator follows selection (SwiftUI); page motion is UIKit.
    static let slide = Animation.easeOut(duration: settleDuration)
    /// Wait until the slide finishes before chrome resets.
    static let settleMilliseconds: UInt64 = 240
}

/// Horizontal paging between expense segments — History / Overview / Friends.
/// Uses UIKit frame animation (same approach as FeedContentPager) so heavy SwiftUI
/// pages slide as layers instead of being re-laid out every animation frame.
struct ExpenseContentPager<History: View, Overview: View, Friends: View>: View {
    @Binding var selection: ExpenseContentSegment
    @ViewBuilder var history: () -> History
    @ViewBuilder var overview: () -> Overview
    @ViewBuilder var friends: () -> Friends

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)

            ExpensePagerHostRep(
                selection: $selection,
                width: width,
                height: height,
                history: {
                    history().modifier(
                        ExpensePagerEnvironmentForwarding(
                            languageService: languageService,
                            tabBarScrollState: tabBarScrollState,
                            feedSegmentScrollState: feedSegmentScrollState,
                            pullToRefreshActive: pullToRefreshActive,
                            scrollChromeTrackingEnabled: selection == .history
                        )
                    )
                },
                overview: {
                    overview().modifier(
                        ExpensePagerEnvironmentForwarding(
                            languageService: languageService,
                            tabBarScrollState: tabBarScrollState,
                            feedSegmentScrollState: feedSegmentScrollState,
                            pullToRefreshActive: pullToRefreshActive,
                            scrollChromeTrackingEnabled: selection == .overview
                        )
                    )
                },
                friends: {
                    friends().modifier(
                        ExpensePagerEnvironmentForwarding(
                            languageService: languageService,
                            tabBarScrollState: tabBarScrollState,
                            feedSegmentScrollState: feedSegmentScrollState,
                            pullToRefreshActive: pullToRefreshActive,
                            scrollChromeTrackingEnabled: selection == .friends
                        )
                    )
                }
            )
            .frame(width: width, height: height)
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Environment forwarding (UIHostingController drops outer env)

private struct ExpensePagerEnvironmentForwarding: ViewModifier {
    let languageService: LanguageService
    let tabBarScrollState: TabBarScrollState?
    let feedSegmentScrollState: FeedSegmentScrollState?
    let pullToRefreshActive: Bool
    let scrollChromeTrackingEnabled: Bool

    func body(content: Content) -> some View {
        content
            .environmentObject(languageService)
            .environment(\.tabBarScrollState, tabBarScrollState)
            .environment(\.feedSegmentScrollState, feedSegmentScrollState)
            .environment(\.pullToRefreshActive, pullToRefreshActive)
            .environment(\.scrollChromeTrackingEnabled, scrollChromeTrackingEnabled)
    }
}

// MARK: - Gesture / layout state

private final class ExpensePagerState {
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

@MainActor
private final class ExpensePagerActivityState: ObservableObject {
    @Published var activeSelection: ExpenseContentSegment

    init(activeSelection: ExpenseContentSegment) {
        self.activeSelection = activeSelection
    }
}

private final class ExpensePagerGestureCoordinator: NSObject, UIGestureRecognizerDelegate {
    let state = ExpensePagerState()
    var onSelectionChanged: ((ExpenseContentSegment) -> Void)?
    var onInteractiveDragChanged: ((CGFloat) -> Void)?
    var onSettled: ((_ targetIndex: Int, _ adjustedOffset: CGFloat) -> Void)?

    private weak var hostView: UIView?
    private var dragAxis: Axis?
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

        guard dragAxis == .horizontal else { return }
        lockVerticalScrollingIfNeeded()
        let raw = translation.x
        let atLeft = state.currentIndex == 0 && raw > 0
        let atRight = state.currentIndex == expenseSegmentStripOrder.count - 1 && raw < 0
        state.drag(to: (atLeft || atRight) ? raw * 0.20 : raw)
        onInteractiveDragChanged?(state.dragOffset)
    }

    func handleEnded(translation: CGPoint, velocity: CGPoint, containerWidth: CGFloat) {
        let resolvedAxis = dragAxis
        dragAxis = nil
        unlockVerticalScrolling()
        guard resolvedAxis == .horizontal else { return }

        let threshold = containerWidth * 0.28
        var target = state.currentIndex
        if translation.x < -threshold || velocity.x < -350 {
            target = min(state.currentIndex + 1, expenseSegmentStripOrder.count - 1)
        } else if translation.x > threshold || velocity.x > 350 {
            target = max(state.currentIndex - 1, 0)
        }

        let adjustedOffset = CGFloat(target - state.currentIndex) * containerWidth + state.dragOffset
        state.currentIndex = target
        state.dragOffset = 0
        onSettled?(target, adjustedOffset)
        onSelectionChanged?(expenseSegmentStripOrder[target])
    }

    private func lockVerticalScrollingIfNeeded() {
        guard scrollLockStates.isEmpty, let hostView else { return }
        func walk(_ view: UIView) {
            if let scrollView = view as? UIScrollView {
                scrollLockStates.append((scrollView, scrollView.isScrollEnabled))
                scrollView.isScrollEnabled = false
            }
            view.subviews.forEach(walk)
        }
        walk(hostView)
    }

    private func unlockVerticalScrolling() {
        scrollLockStates.forEach { $0.0.isScrollEnabled = $0.1 }
        scrollLockStates = []
    }

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard let pan = recognizer as? UIPanGestureRecognizer,
              let hostView = pan.view else { return true }
        let velocity = pan.velocity(in: hostView)
        let total = abs(velocity.x) + abs(velocity.y)
        guard total > 20 else { return true }
        return abs(velocity.x) * 2 >= abs(velocity.y)
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        guard other is UIPanGestureRecognizer else { return false }
        return dragAxis != .horizontal
    }
}

// MARK: - UIViewControllerRepresentable

private struct ExpensePagerHostRep<History: View, Overview: View, Friends: View>: UIViewControllerRepresentable {
    @Binding var selection: ExpenseContentSegment
    let width: CGFloat
    let height: CGFloat
    let history: () -> History
    let overview: () -> Overview
    let friends: () -> Friends

    func makeCoordinator() -> ExpensePagerGestureCoordinator {
        ExpensePagerGestureCoordinator()
    }

    func makeUIViewController(context: Context) -> ExpensePagerContainerVC<History, Overview, Friends> {
        let coordinator = context.coordinator
        coordinator.state.currentIndex = expenseSegmentStripOrder.firstIndex(of: selection) ?? 1
        return ExpensePagerContainerVC(
            coordinator: coordinator,
            width: width,
            height: height,
            activeSelection: selection,
            history: history,
            overview: overview,
            friends: friends
        )
    }

    func updateUIViewController(
        _ viewController: ExpensePagerContainerVC<History, Overview, Friends>,
        context: Context
    ) {
        let coordinator = context.coordinator
        coordinator.onSelectionChanged = { selection = $0 }

        let idx = expenseSegmentStripOrder.firstIndex(of: selection) ?? 1
        if idx != coordinator.state.currentIndex {
            viewController.animateTo(idx)
        }

        viewController.updatePages(
            history: history,
            overview: overview,
            friends: friends,
            width: width,
            height: height,
            activeSelection: selection
        )
    }
}

// MARK: - Container

private struct ExpensePagerPageRoot<Content: View>: View {
    let segment: ExpenseContentSegment
    @ObservedObject var activityState: ExpensePagerActivityState
    let content: Content

    var body: some View {
        content.environment(\.scrollChromeTrackingEnabled, activityState.activeSelection == segment)
    }
}

private final class ExpensePagerContainerVC<History: View, Overview: View, Friends: View>: UIViewController {
    private let coordinator: ExpensePagerGestureCoordinator
    private let activityState: ExpensePagerActivityState
    private var historyHosting: UIHostingController<ExpensePagerPageRoot<History>>?
    private var overviewHosting: UIHostingController<ExpensePagerPageRoot<Overview>>?
    private var friendsHosting: UIHostingController<ExpensePagerPageRoot<Friends>>?

    private var currentHistory: () -> History
    private var currentOverview: () -> Overview
    private var currentFriends: () -> Friends
    private var currentWidth: CGFloat
    private var currentHeight: CGFloat
    private var activeSelection: ExpenseContentSegment
    private var mountedIndices: Set<Int> = []

    init(
        coordinator: ExpensePagerGestureCoordinator,
        width: CGFloat,
        height: CGFloat,
        activeSelection: ExpenseContentSegment,
        history: @escaping () -> History,
        overview: @escaping () -> Overview,
        friends: @escaping () -> Friends
    ) {
        self.coordinator = coordinator
        self.activityState = ExpensePagerActivityState(activeSelection: activeSelection)
        self.currentWidth = width
        self.currentHeight = height
        self.activeSelection = activeSelection
        self.currentHistory = history
        self.currentOverview = overview
        self.currentFriends = friends
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = true

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)

        bindCoordinatorCallbacks()
        coordinator.attachHostView(view)
        ensureMounted(at: expenseSegmentStripOrder.firstIndex(of: activeSelection) ?? 1)
        applyLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyLayout()
    }

    private func bindCoordinatorCallbacks() {
        coordinator.onInteractiveDragChanged = { [weak self] _ in
            self?.applyLayout()
        }
        coordinator.onSettled = { [weak self] targetIndex, adjustedOffset in
            self?.ensureMounted(at: targetIndex)
            self?.settle(to: targetIndex, adjustedOffset: adjustedOffset)
        }
    }

    private func ensureMounted(at index: Int) {
        guard expenseSegmentStripOrder.indices.contains(index),
              !mountedIndices.contains(index) else { return }
        mountedIndices.insert(index)

        switch expenseSegmentStripOrder[index] {
        case .history:
            let hosting = UIHostingController(rootView: makeHistoryRoot())
            prepareHost(hosting)
            historyHosting = hosting
        case .overview:
            let hosting = UIHostingController(rootView: makeOverviewRoot())
            prepareHost(hosting)
            overviewHosting = hosting
        case .friends:
            let hosting = UIHostingController(rootView: makeFriendsRoot())
            prepareHost(hosting)
            friendsHosting = hosting
        }
    }

    private func prepareHost<Content: View>(_ hosting: UIHostingController<Content>) {
        hosting.view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            hosting.safeAreaRegions = []
        }
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    private func makeHistoryRoot() -> ExpensePagerPageRoot<History> {
        ExpensePagerPageRoot(segment: .history, activityState: activityState, content: currentHistory())
    }

    private func makeOverviewRoot() -> ExpensePagerPageRoot<Overview> {
        ExpensePagerPageRoot(segment: .overview, activityState: activityState, content: currentOverview())
    }

    private func makeFriendsRoot() -> ExpensePagerPageRoot<Friends> {
        ExpensePagerPageRoot(segment: .friends, activityState: activityState, content: currentFriends())
    }

    private var hostedPageViews: [UIView?] {
        [historyHosting?.view, overviewHosting?.view, friendsHosting?.view]
    }

    private func applyLayout() {
        guard isViewLoaded else { return }
        let width = max(currentWidth, view.bounds.width, 1)
        let height = max(currentHeight, view.bounds.height, 1)

        for (index, pageView) in hostedPageViews.enumerated() {
            guard let pageView else { continue }
            let x = CGFloat(index - coordinator.state.currentIndex) * width + coordinator.state.dragOffset
            pageView.frame = CGRect(x: x, y: 0, width: width, height: height)
        }
    }

    private func settle(to targetIndex: Int, adjustedOffset: CGFloat) {
        coordinator.state.currentIndex = targetIndex
        coordinator.state.dragOffset = adjustedOffset
        applyLayout()

        coordinator.state.dragOffset = 0
        UIView.animate(
            withDuration: ExpensePagerMotion.settleDuration,
            delay: 0,
            usingSpringWithDamping: ExpensePagerMotion.settleDamping,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) { [weak self] in
            self?.applyLayout()
        }
    }

    func animateTo(_ index: Int) {
        let from = coordinator.state.currentIndex
        guard index != from, expenseSegmentStripOrder.indices.contains(index) else { return }

        for mountedIndex in min(from, index)...max(from, index) {
            ensureMounted(at: mountedIndex)
        }

        let width = max(currentWidth, view.bounds.width, 1)
        settle(to: index, adjustedOffset: CGFloat(index - from) * width)
    }

    func updatePages(
        history: @escaping () -> History,
        overview: @escaping () -> Overview,
        friends: @escaping () -> Friends,
        width: CGFloat,
        height: CGFloat,
        activeSelection: ExpenseContentSegment
    ) {
        let geometryChanged = width != currentWidth || height != currentHeight
        currentHistory = history
        currentOverview = overview
        currentFriends = friends
        currentWidth = width
        currentHeight = height
        self.activeSelection = activeSelection

        if activityState.activeSelection != activeSelection {
            Task { @MainActor in
                activityState.activeSelection = activeSelection
            }
        }

        if let index = expenseSegmentStripOrder.firstIndex(of: activeSelection) {
            ensureMounted(at: index)
        }
        if mountedIndices.contains(0), let historyHosting {
            historyHosting.rootView = makeHistoryRoot()
        }
        if mountedIndices.contains(1), let overviewHosting {
            overviewHosting.rootView = makeOverviewRoot()
        }
        if mountedIndices.contains(2), let friendsHosting {
            friendsHosting.rootView = makeFriendsRoot()
        }

        if geometryChanged {
            applyLayout()
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        let velocity = pan.velocity(in: view)

        switch pan.state {
        case .began:
            coordinator.handleBegin()
            let current = coordinator.state.currentIndex
            ensureMounted(at: max(current - 1, 0))
            ensureMounted(at: min(current + 1, expenseSegmentStripOrder.count - 1))
        case .changed:
            coordinator.handleChanged(translation: CGPoint(x: translation.x, y: translation.y))
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
