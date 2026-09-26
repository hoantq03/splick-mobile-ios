import SwiftUI
import UIKit
import DesignSystem
import FeatureSocialFeed

/// Horizontal main-tab pager. Pages keep fixed bounds and slide with `transform`
/// so SwiftUI does not re-layout feed/lists on every animation frame.
struct MainTabContentPager<Feed: View, Expenses: View, Friends: View, Messages: View>: View {
    @Binding var selectedTab: Tab
    var onSlideSettled: (Tab) -> Void
    /// Identity for hosted tab roots. Chrome-only publishes (thread presented, tab-bar hide)
    /// must not rewrite four UIHostingController roots mid-navigation.
    var contentEpoch: Int = 0
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var expenses: () -> Expenses
    @ViewBuilder var friends: () -> Friends
    @ViewBuilder var messages: () -> Messages

    var body: some View {
        MainTabPagerHost(
            selectedTab: selectedTab,
            onSlideSettled: onSlideSettled,
            contentEpoch: contentEpoch,
            feed: feed(),
            expenses: expenses(),
            friends: friends(),
            messages: messages()
        )
        .ignoresSafeArea(edges: [.top, .bottom])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MainTabPageRoot<Content: View>: View {
    var environment: EnvironmentValues
    var content: Content

    var body: some View {
        content
            .environment(\.self, environment)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MainTabPagerHost<Feed: View, Expenses: View, Friends: View, Messages: View>: UIViewControllerRepresentable {
    var selectedTab: Tab
    var onSlideSettled: (Tab) -> Void
    var contentEpoch: Int
    var feed: Feed
    var expenses: Expenses
    var friends: Friends
    var messages: Messages

    func makeUIViewController(context: Context) -> MainTabPagerContainerVC<Feed, Expenses, Friends, Messages> {
        MainTabPagerContainerVC(
            initialTab: selectedTab.isPagerTab ? selectedTab : .feed,
            environment: context.environment,
            contentEpoch: contentEpoch,
            feed: feed,
            expenses: expenses,
            friends: friends,
            messages: messages
        )
    }

    func updateUIViewController(
        _ uiViewController: MainTabPagerContainerVC<Feed, Expenses, Friends, Messages>,
        context: Context
    ) {
        uiViewController.onSlideSettled = onSlideSettled
        uiViewController.update(
            selectedTab: selectedTab,
            environment: context.environment,
            contentEpoch: contentEpoch,
            feed: feed,
            expenses: expenses,
            friends: friends,
            messages: messages
        )
    }
}

private final class MainTabPagerContainerVC<Feed: View, Expenses: View, Friends: View, Messages: View>: UIViewController {
    var onSlideSettled: ((Tab) -> Void)?

    private var swiftUIEnvironment: EnvironmentValues
    private var currentFeed: Feed
    private var currentExpenses: Expenses
    private var currentFriends: Friends
    private var currentMessages: Messages

    private var feedHost: UIHostingController<MainTabPageRoot<Feed>>?
    private var expensesHost: UIHostingController<MainTabPageRoot<Expenses>>?
    private var friendsHost: UIHostingController<MainTabPageRoot<Friends>>?
    private var messagesHost: UIHostingController<MainTabPageRoot<Messages>>?

    private var mountedTabs: Set<Tab> = []
    private var currentIndex: Int
    private var targetIndex: Int
    private var outgoingIndex: Int
    private var lastRequestedTab: Tab?
    private var laidOutSize: CGSize = .zero
    private var animator: UIViewPropertyAnimator?
    private var transitionGeneration: Int = 0
    private var pendingRootRefresh = false
    private var lastAppliedContentEpoch: Int
    private var latestContentEpoch: Int

    init(
        initialTab: Tab,
        environment: EnvironmentValues,
        contentEpoch: Int,
        feed: Feed,
        expenses: Expenses,
        friends: Friends,
        messages: Messages
    ) {
        let index = Tab.pagerTabs.firstIndex(of: initialTab) ?? 0
        self.currentIndex = index
        self.targetIndex = index
        self.outgoingIndex = index
        self.swiftUIEnvironment = environment
        self.currentFeed = feed
        self.currentExpenses = expenses
        self.currentFriends = friends
        self.currentMessages = messages
        self.lastAppliedContentEpoch = contentEpoch
        self.latestContentEpoch = contentEpoch
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private var isAnimating: Bool {
        animator?.isRunning == true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        ensureMounted(Tab.pagerTabs[currentIndex])
        applyPageSizes()
        applyTransforms(index: currentIndex)
        applySettledVisibility(index: currentIndex)
        prewarmRemainingTabs()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = view.bounds.size
        guard size.width > 1, size.height > 1 else { return }
        guard size != laidOutSize else { return }
        laidOutSize = size
        applyPageSizes()
        if !isAnimating {
            applyTransforms(index: currentIndex)
        }
    }

    func update(
        selectedTab: Tab,
        environment: EnvironmentValues,
        contentEpoch: Int,
        feed: Feed,
        expenses: Expenses,
        friends: Friends,
        messages: Messages
    ) {
        swiftUIEnvironment = environment
        currentFeed = feed
        currentExpenses = expenses
        currentFriends = friends
        currentMessages = messages

        let previousRequest = lastRequestedTab
        let tabChanged = previousRequest != selectedTab
        lastRequestedTab = selectedTab
        latestContentEpoch = contentEpoch
        let epochChanged = lastAppliedContentEpoch != contentEpoch

        let idx = selectedTab.isPagerTab ? (Tab.pagerTabs.firstIndex(of: selectedTab) ?? 0) : targetIndex
        let leavingFeed = selectedTab != .feed
            && (Tab.pagerTabs[currentIndex] == .feed || Tab.pagerTabs[outgoingIndex] == .feed)

        if selectedTab.isPagerTab, idx != targetIndex {
            pendingRootRefresh = true
            if leavingFeed {
                FeedVideoPlaybackControl.suspend()
            }
            moveTo(index: idx, animated: laidOutSize.width > 1)
            return
        }

        if isAnimating {
            pendingRootRefresh = true
        } else if selectedTab.isPagerTab, epochChanged {
            lastAppliedContentEpoch = contentEpoch
            refreshMountedRoots()
        }

        if selectedTab.isPagerTab, tabChanged, previousRequest != nil, !isAnimating {
            onSlideSettled?(selectedTab)
        }
    }

    private func prewarmRemainingTabs() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            UIView.performWithoutAnimation {
                for tab in Tab.pagerTabs {
                    self.ensureMounted(tab)
                }
                self.applyPageSizes()
                guard !self.isAnimating else {
                    for (i, pageView) in self.hostedPageViews.enumerated() {
                        if i != self.outgoingIndex && i != self.currentIndex {
                            pageView?.isHidden = true
                        }
                    }
                    return
                }
                self.applyTransforms(index: self.currentIndex)
                self.applySettledVisibility(index: self.currentIndex)
            }
        }
    }

    private func moveTo(index: Int, animated: Bool) {
        let interrupting = animator?.isRunning == true
        if interrupting, let animator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
            self.animator = nil
        } else {
            outgoingIndex = currentIndex
        }

        targetIndex = index
        transitionGeneration += 1
        let generation = transitionGeneration

        let lower = min(outgoingIndex, currentIndex, index)
        let upper = max(outgoingIndex, currentIndex, index)
        UIView.performWithoutAnimation {
            for i in lower...upper {
                ensureMounted(Tab.pagerTabs[i])
            }
            applyPageSizes()
        }

        applyTransitionVisibility(hitsIndex: outgoingIndex, visible: Set([outgoingIndex, currentIndex, index]))

        if !animated {
            currentIndex = index
            applyTransforms(index: index)
            settle(index: index, generation: generation)
            return
        }

        currentIndex = index
        let slide = UIViewPropertyAnimator(
            duration: SplickPageSlideMotion.duration,
            curve: .easeOut
        )
        slide.addAnimations { [weak self] in
            self?.applyTransforms(index: index)
        }
        slide.addCompletion { [weak self] position in
            guard let self, generation == self.transitionGeneration else { return }
            self.animator = nil
            guard position == .end else { return }
            self.settle(index: index, generation: generation)
        }
        animator = slide
        slide.startAnimation()
    }

    private func settle(index: Int, generation: Int) {
        guard generation == transitionGeneration else { return }
        applySettledVisibility(index: index)
        if pendingRootRefresh {
            pendingRootRefresh = false
            lastAppliedContentEpoch = latestContentEpoch
            refreshMountedRoots()
        }
        onSlideSettled?(Tab.pagerTabs[index])
    }

    private func applyTransitionVisibility(hitsIndex: Int, visible: Set<Int>) {
        for (i, pageView) in hostedPageViews.enumerated() {
            pageView?.isHidden = !visible.contains(i)
            pageView?.isUserInteractionEnabled = i == hitsIndex
        }
    }

    private func applySettledVisibility(index: Int) {
        outgoingIndex = index
        for (i, pageView) in hostedPageViews.enumerated() {
            pageView?.isHidden = i != index
            pageView?.isUserInteractionEnabled = i == index
        }
    }

    private var hostedPageViews: [UIView?] {
        [
            feedHost?.view,
            expensesHost?.view,
            friendsHost?.view,
            messagesHost?.view,
        ]
    }

    private func applyPageSizes() {
        let size = view.bounds.size
        guard size.width > 1, size.height > 1 else { return }
        let bounds = CGRect(origin: .zero, size: size)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for pageView in hostedPageViews {
            guard let pageView else { continue }
            pageView.bounds = bounds
            pageView.center = center
        }
    }

    private func applyTransforms(index: Int) {
        let width = max(view.bounds.width, 1)
        for (pageIndex, pageView) in hostedPageViews.enumerated() {
            guard let pageView else { continue }
            pageView.transform = CGAffineTransform(
                translationX: CGFloat(pageIndex - index) * width,
                y: 0
            )
        }
    }

    private func ensureMounted(_ tab: Tab) {
        guard !mountedTabs.contains(tab) else { return }
        mountedTabs.insert(tab)
        switch tab {
        case .feed:
            let hosting = UIHostingController(rootView: makeFeedRoot())
            prepareHost(hosting)
            feedHost = hosting
        case .expenses:
            let hosting = UIHostingController(rootView: makeExpensesRoot())
            prepareHost(hosting)
            expensesHost = hosting
        case .friends:
            let hosting = UIHostingController(rootView: makeFriendsRoot())
            prepareHost(hosting)
            friendsHost = hosting
        case .messages:
            let hosting = UIHostingController(rootView: makeMessagesRoot())
            prepareHost(hosting)
            messagesHost = hosting
        case .camera, .profile:
            break
        }
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

    private func refreshMountedRoots() {
        if let feedHost {
            feedHost.rootView = makeFeedRoot()
        }
        if let expensesHost {
            expensesHost.rootView = makeExpensesRoot()
        }
        if let friendsHost {
            friendsHost.rootView = makeFriendsRoot()
        }
        if let messagesHost {
            messagesHost.rootView = makeMessagesRoot()
        }
    }

    private func makeFeedRoot() -> MainTabPageRoot<Feed> {
        MainTabPageRoot(environment: swiftUIEnvironment, content: currentFeed)
    }

    private func makeExpensesRoot() -> MainTabPageRoot<Expenses> {
        MainTabPageRoot(environment: swiftUIEnvironment, content: currentExpenses)
    }

    private func makeFriendsRoot() -> MainTabPageRoot<Friends> {
        MainTabPageRoot(environment: swiftUIEnvironment, content: currentFriends)
    }

    private func makeMessagesRoot() -> MainTabPageRoot<Messages> {
        MainTabPageRoot(environment: swiftUIEnvironment, content: currentMessages)
    }
}
