import SwiftUI
import Combine
import UIKit
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureFriends
import FeatureStickers

private struct ProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}

public struct FeedView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject private var viewModel: FeedViewModel
    @Binding private var navigationPath: NavigationPath
    private let pendingFeedPostNavigation: PendingFeedPostNavigation?
    private let onPendingPostHandled: (() -> Void)?
    @Environment(\.openPostCaptureFlow) private var openPostCaptureFlow

    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.notificationsPresented) private var notificationsPresented
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.sameTabTapHandlingEnabled) private var sameTabTapHandlingEnabled
    @Environment(\.scenePhase) private var scenePhase
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?
    private let profileDependencies: FriendUserProfileDependencies?
    private let makeGifPickerViewModel: GifPickerViewModelFactory?
    private let photoAlbumViewModel: PhotoAlbumViewModel
    private let streakViewModel: StreakViewModel
    private let isTabActive: Bool
    @State private var profileRoute: ProfileRoute?
    @State private var companionsRoute: CompanionsSheetRoute?
    @State private var selectedSegment: FeedContentSegment = .feed
    @StateObject private var scrollChrome = ScrollChromeStateHolder()
    @StateObject private var videoCoordinator = FeedVideoPlaybackCoordinator()
    @State private var feedScrollTopSignal = 0
    @State private var feedSameTabRefreshSignal = 0
    @Namespace private var postZoomNamespace

    public init(
        viewModel: FeedViewModel,
        photoAlbumViewModel: PhotoAlbumViewModel,
        streakViewModel: StreakViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol? = nil,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil,
        makeGifPickerViewModel: GifPickerViewModelFactory? = nil,
        navigationPath: Binding<NavigationPath> = .constant(NavigationPath()),
        pendingFeedPostNavigation: PendingFeedPostNavigation? = nil,
        onPendingPostHandled: (() -> Void)? = nil,
        isTabActive: Bool = true
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.photoAlbumViewModel = photoAlbumViewModel
        self.streakViewModel = streakViewModel
        _navigationPath = navigationPath
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.profileDependencies = profileDependencies
        self.makeGifPickerViewModel = makeGifPickerViewModel
        self.pendingFeedPostNavigation = pendingFeedPostNavigation
        self.onPendingPostHandled = onPendingPostHandled
        self.isTabActive = isTabActive
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            FeedContentPager(
                selection: $selectedSegment,
                sameTabTapHandlingEnabled: sameTabTapHandlingEnabled && navigationPath.isEmpty,
                scrollTopSignal: feedScrollTopSignal,
                sameTabRefreshSignal: feedSameTabRefreshSignal
            ) {
                FeedPrimaryPage(
                    viewModel: viewModel,
                    navigationPath: $navigationPath,
                    companionsRoute: $companionsRoute,
                    videoCoordinator: videoCoordinator,
                    makeGifPickerViewModel: makeGifPickerViewModel,
                    onOpenProfile: openProfile
                )
            } album: {
                PhotoAlbumView(
                    viewModel: photoAlbumViewModel,
                    feedViewModel: viewModel,
                    navigationPath: $navigationPath,
                    fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                    fetchMyGroupsUseCase: fetchMyGroupsUseCase,
                    isEmbedded: true
                )
            } streak: {
                StreakView(
                    viewModel: streakViewModel,
                    feedViewModel: viewModel,
                    navigationPath: $navigationPath
                )
            }
            .environment(\.pullToRefreshActive, viewModel.isRefreshing)
            .background(SplickTheme.Colors.background.ignoresSafeArea())
            .splickInteractivePopEnabled()
            .navigationTitle("")
            .splickTabNavigationBarChrome()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !notificationsPresented {
                        FeedNavPills(
                            selection: $selectedSegment,
                            scrollState: scrollChrome.feedSegment,
                            feedLabel: languageService.text(.feedTitle),
                            albumLabel: languageService.text(.feedAlbumTitle),
                            streakLabel: languageService.text(.feedStreakTitle)
                        )
                    }
                }
            }
            .overlay(alignment: .top) {
                FeedScrollTopFadeOverlay()
            }
            .overlay(alignment: .top) {
                if selectedSegment == .feed, navigationPath.isEmpty, !notificationsPresented {
                    FeedNewPostsPillOverlay(
                        count: viewModel.isRefreshing ? 0 : viewModel.newPostsCount,
                        onTap: revealNewPostsFromPill
                    )
                }
            }
            .navigationDestination(for: FeedPostDestination.self) { destination in
                PostDetailContainerView(
                    destination: destination,
                    feedViewModel: viewModel,
                    fetchFriendsUseCase: fetchFriendsUseCase,
                    profileDependencies: profileDependencies,
                    makeGifPickerViewModel: makeGifPickerViewModel
                )
                .feedPostZoomDestination(postId: destination.postId, namespace: postZoomNamespace)
            }
            .alert(
                languageService.text(.commonError),
                isPresented: Binding(
                    get: { viewModel.alertMessage != nil },
                    set: { if !$0 { viewModel.alertMessage = nil } }
                )
            ) {
                Button(languageService.text(.commonOK), role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .alert(
                languageService.text(.feedPostDelete),
                isPresented: Binding(
                    get: { viewModel.pendingStreakDelete != nil },
                    set: { if !$0 { viewModel.dismissPendingStreakDelete() } }
                )
            ) {
                Button(languageService.text(.commonCancel), role: .cancel) {
                    viewModel.dismissPendingStreakDelete()
                }
                Button(languageService.text(.feedPostDelete), role: .destructive) {
                    Task { await viewModel.confirmPendingStreakDelete() }
                }
            } message: {
                if let days = viewModel.pendingStreakDelete?.streakDays {
                    Text(languageService.format(.feedPostDeleteStreakWarning, days))
                }
            }
        }
        .environment(\.feedSegmentScrollState, scrollChrome.feedSegment)
        .environment(\.feedPostZoomNamespace, postZoomNamespace)
        .onChange(of: navigationPath.isEmpty) { isEmpty in
            if isEmpty {
                tabBarScrollState?.show()
            }
        }
        .onFirstAppear {
            viewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
        }
        .onChange(of: currentUserSummary?.id) { _ in
            viewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
        }
        .task(id: pendingFeedPostNavigation) {
            guard let navigation = pendingFeedPostNavigation else { return }
            let result = await viewModel.ensurePostLoaded(id: navigation.postId)
            if result == .loaded {
                withFeedPostNavigation {
                    navigationPath.append(
                        FeedPostDestination(
                            postId: navigation.postId,
                            mediaIndex: 0,
                            expandBillSplit: navigation.expandBillSplit,
                            commentId: navigation.commentId
                        )
                    )
                }
            }
            onPendingPostHandled?()
        }
        .onChange(of: isTabActive) { active in
            if !active {
                videoCoordinator.suspendPlayback()
            }
        }
        .onChange(of: selectedSegment) { segment in
            if segment != .feed {
                videoCoordinator.suspendPlayback()
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                scrollChrome.feedSegment.reset()
                tabBarScrollState?.reset()
            }
        }
        .onChange(of: viewModel.state) { state in
            guard selectedSegment == .feed else { return }
            if case .loaded(let posts) = state, posts.isEmpty {
                Task { @MainActor in
                    tabBarScrollState?.show()
                    scrollChrome.feedSegment.reset()
                }
            }
        }
        .environment(\.feedTabIsActive, isTabActive && selectedSegment == .feed)
        .task(id: "\(isTabActive)-\(selectedSegment)-\(scenePhase)") {
            guard isTabActive, selectedSegment == .feed, scenePhase == .active else { return }
            await viewModel.pollNewPostsWhileActive()
        }
        .onChange(of: viewModel.posts.first?.id) { _ in
            guard isTabActive, selectedSegment == .feed, scenePhase == .active else { return }
            Task { await viewModel.refreshNewPostsCountIfNeeded() }
        }
        .onReceive(sameTabTapPublisher) { _ in
            handleSameTabTap()
        }
        .sheet(item: $profileRoute) { route in
            if let profileDependencies {
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(
                        user: route.user,
                        currentUserId: currentUserSummary?.id
                    )
                )
            }
        }
        .sheet(item: $companionsRoute) { route in
            CompanionsListSheet(
                companions: route.companions,
                currentUserId: currentUserSummary?.id
            ) { user in
                companionsRoute = nil
                openProfile(for: user)
            }
        }
        .sheet(item: $viewModel.pendingGuestInviteShare) { payload in
            GuestBillInviteShareSheet(message: payload.message, urls: payload.urls)
        }
    }

    private func openProfile(for user: UserSummary) {
        profileRoute = ProfileRoute(user: user)
    }

    private func revealNewPostsFromPill() {
        viewModel.revealNewPosts()
        feedScrollTopSignal += 1
        feedSameTabRefreshSignal += 1
    }

    private func handleSameTabTap() {
        guard sameTabTapHandlingEnabled, isTabActive else { return }

        if !navigationPath.isEmpty {
            navigationPath = NavigationPath()
            tabBarScrollState?.show()
            return
        }

        if selectedSegment != .feed {
            selectedSegment = .feed
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                guard selectedSegment == .feed, isTabActive else { return }
                feedSameTabRefreshSignal += 1
            }
            return
        }

        if tabBarScrollState?.isAtTop ?? true {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            feedSameTabRefreshSignal += 1
        } else {
            feedScrollTopSignal += 1
            tabBarScrollState?.reset()
            scrollChrome.feedSegment.reset()
        }
    }

    private var sameTabTapPublisher: AnyPublisher<Void, Never> {
        tabBarScrollState?.sameTabTapSubject.eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }
}

private struct FeedPrimaryPage: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.openPostCaptureFlow) private var openPostCaptureFlow
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.feedTabIsActive) private var feedTabIsActive
    @ObservedObject var viewModel: FeedViewModel
    @Binding var navigationPath: NavigationPath
    @Binding var companionsRoute: CompanionsSheetRoute?
    let videoCoordinator: FeedVideoPlaybackCoordinator
    let makeGifPickerViewModel: GifPickerViewModelFactory?
    let onOpenProfile: (UserSummary) -> Void

    @State private var feedScrollLocked = false
    @State private var cardPresentation: PostCardPresentation?
    @State private var editingPost: Post?
    @StateObject private var cardActions = PostCardActions()

    var body: some View {
        feedPane
            .onAppear {
                viewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
                configureCardActions()
                Task { await viewModel.loadFeedIfNeeded() }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: FeedScrollLock.notification)
            ) { notification in
                feedScrollLocked = notification.userInfo?["locked"] as? Bool ?? false
            }
            .postCardPresentationHost(
                presentation: $cardPresentation,
                currentUser: viewModel.currentUser,
                languageService: languageService,
                onUserTap: onOpenProfile,
                onReact: { postId, emoji in
                    if let error = viewModel.react(to: postId, emoji: emoji) {
                        viewModel.alertMessage = error
                    }
                },
                loadReactions: { postId in
                    try await viewModel.loadPostReactions(postId: postId)
                },
                onSubmitPaymentEvidence: { postId, splitId, message, attachments in
                    try await viewModel.submitPaymentEvidence(
                        postId: postId,
                        splitId: splitId,
                        message: message,
                        submissionAttachments: attachments
                    )
                },
                loadPostEdits: { postId in
                    try await viewModel.fetchPostEdits(postId: postId)
                },
                customEmojiDependencies: customEmojiDependencies
            )
            .fullScreenCover(item: $editingPost) { post in
                EditPostComposeView(
                    post: post,
                    updatePost: { try await viewModel.updatePost($0) },
                    onSaved: { _ in editingPost = nil },
                    onCancel: { editingPost = nil }
                )
                .environmentObject(languageService)
            }
    }

    private func configureCardActions() {
        cardActions.onReact = { postId, emoji in
            if let error = viewModel.react(to: postId, emoji: emoji) {
                viewModel.alertMessage = error
            }
        }
        cardActions.onDelete = { postId in
            Task { await viewModel.requestDelete(id: postId) }
        }
        cardActions.onEdit = { post in
            editingPost = post
        }
        cardActions.onUserTap = onOpenProfile
        cardActions.onShowCompanions = { post in
            companionsRoute = CompanionsSheetRoute(id: post.id, companions: post.companions)
        }
        cardActions.onOpenComments = { post in
            guard viewModel.postUploadState(for: post.id) == nil else { return }
            withFeedPostNavigation {
                navigationPath.append(
                    FeedPostDestination(
                        postId: post.id,
                        mediaIndex: 0,
                        focusComposerOnAppear: post.commentCount == 0
                    )
                )
            }
        }
        cardActions.onOpenDetail = { post, mediaIndex in
            guard viewModel.postUploadState(for: post.id) == nil else { return }
            withFeedPostNavigation {
                navigationPath.append(FeedPostDestination(postId: post.id, mediaIndex: mediaIndex))
            }
        }
        cardActions.onPresent = { presentation in
            cardPresentation = presentation
        }
        cardActions.onSendBillReminder = { postId, targetUserIds, message, attachments in
            try await viewModel.sendBillReminder(
                postId: postId,
                targetUserIds: targetUserIds,
                message: message,
                submissionAttachments: attachments
            )
        }
        cardActions.onSubmitPaymentEvidence = { postId, splitId, message, attachments in
            try await viewModel.submitPaymentEvidence(
                postId: postId,
                splitId: splitId,
                message: message,
                submissionAttachments: attachments
            )
        }
        cardActions.makeGifPickerViewModel = makeGifPickerViewModel
    }

    @ViewBuilder
    private var feedPane: some View {
        switch viewModel.state {
        case .idle, .loading:
            if !viewModel.posts.isEmpty {
                feedList
            } else {
                FeedSkeletonLoadingView()
                    .feedPagerPageTopInset(isEnabled: true)
            }

        case .loaded(let posts) where posts.isEmpty:
            feedRefreshScroll {
                GeometryReader { geo in
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: languageService.text(.feedEmptyTitle),
                        message: languageService.text(.feedEmptyMessage),
                        actionTitle: languageService.text(.feedEmptyAction)
                    ) {
                        openPostCaptureFlow?()
                    }
                    .frame(width: geo.size.width, height: max(geo.size.height, 1))
                }
                .frame(minHeight: 480)
            }

        case .loaded:
            feedList

        case .failed(let message):
            if !viewModel.posts.isEmpty {
                feedList
            } else {
                feedRefreshScroll {
                    GeometryReader { geo in
                        ErrorView(message: message) {
                            Task { await viewModel.loadFeed() }
                        }
                        .frame(width: geo.size.width, height: max(geo.size.height, 1))
                    }
                    .frame(minHeight: 480)
                }
            }
        }
    }

    private func feedRefreshScroll<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        FeedPullToRefreshScrollView(
            onRefreshWillBegin: { viewModel.beginPullToRefreshIfNeeded() }
        ) {
            FeedScrollLock.forceUnlock()
            feedScrollLocked = false
            defer {
                tabBarScrollState?.reset()
                feedSegmentScrollState?.reset()
                viewModel.endRefreshingIfNeeded()
            }
            return await viewModel.loadFeed(isPullToRefresh: true)
        } content: {
            content()
        }
    }

    private var feedList: some View {
        feedRefreshScroll {
            LazyVStack(spacing: SplickTheme.Spacing.md) {
                ForEach(viewModel.posts) { post in
                    PostCardView(
                        post: post,
                        currentUser: viewModel.currentUser ?? currentUserSummary,
                        actions: cardActions,
                        uploadState: viewModel.postUploadState(for: post.id)
                    )
                    .equatable()
                    .feedPostZoomSource(postId: post.id)
                    .onAppear {
                        guard feedTabIsActive, !viewModel.isRefreshing else { return }
                        Task { await viewModel.trackViewOnScrollIfNeeded(for: post) }
                        if post.id == viewModel.posts.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    SkeletonShimmerHost {
                        FeedPostCardSkeleton(variant: 0)
                    }
                    .padding(.vertical, SplickTheme.Spacing.xxs)
                }

                if viewModel.hasReachedFeedEnd {
                    feedEndReachedFooter
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.md)
        }
        .scrollDisabled(feedScrollLocked)
        .environment(\.feedVideoCoordinator, videoCoordinator)
    }

    private var feedEndReachedFooter: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(SplickTheme.Colors.textTertiary)

            Text(languageService.text(.feedEndReachedTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            Text(languageService.text(.feedEndReachedMessage))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SplickTheme.Spacing.xl)
        .padding(.horizontal, SplickTheme.Spacing.sm)
    }
}

private struct GuestBillInviteShareSheet: UIViewControllerRepresentable {
    let message: String
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = [message]
        items.append(contentsOf: urls)
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
