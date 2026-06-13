import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureFriends

private struct ProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}

public struct FeedView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject private var viewModel: FeedViewModel
    @Binding private var navigationPath: NavigationPath
    private let pendingPostId: UUID?
    private let onPendingPostHandled: (() -> Void)?
    @Environment(\.openPostCaptureFlow) private var openPostCaptureFlow
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?
    private let profileDependencies: FriendUserProfileDependencies?
    private let photoAlbumViewModel: PhotoAlbumViewModel
    private let streakViewModel: StreakViewModel
    private let isTabActive: Bool
    @State private var profileRoute: ProfileRoute?
    @State private var companionsRoute: CompanionsSheetRoute?
    @State private var feedScrollLocked = false
    @State private var selectedSegment: FeedContentSegment = .feed
    @StateObject private var feedSegmentScrollState = FeedSegmentScrollState()
    @StateObject private var videoCoordinator = FeedVideoPlaybackCoordinator()

    public init(
        viewModel: FeedViewModel,
        photoAlbumViewModel: PhotoAlbumViewModel,
        streakViewModel: StreakViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol? = nil,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil,
        navigationPath: Binding<NavigationPath> = .constant(NavigationPath()),
        pendingPostId: UUID? = nil,
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
        self.pendingPostId = pendingPostId
        self.onPendingPostHandled = onPendingPostHandled
        self.isTabActive = isTabActive
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            FeedContentPager(selection: $selectedSegment) {
                feedPane
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
            .background(SplickTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .splickProfileToolbar(titleDisplayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FeedNavPills(
                        selection: $selectedSegment,
                        collapseProgress: feedSegmentScrollState.collapseProgress,
                        feedLabel: languageService.text(.feedTitle),
                        albumLabel: languageService.text(.feedAlbumTitle),
                        streakLabel: languageService.text(.feedStreakTitle)
                    )
                }
            }
            .navigationDestination(for: FeedPostDestination.self) { destination in
                PostDetailContainerView(
                    destination: destination,
                    feedViewModel: viewModel,
                    fetchFriendsUseCase: fetchFriendsUseCase,
                    profileDependencies: profileDependencies
                )
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
        }
        .environment(\.feedSegmentScrollState, feedSegmentScrollState)
        .onFirstAppear {
            viewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
            guard viewModel.posts.isEmpty else { return }
            Task { await viewModel.loadFeed() }
        }
        .onChange(of: currentUserSummary?.id) { _ in
            viewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
        }
        .task(id: pendingPostId) {
            guard let postId = pendingPostId else { return }
            let loaded = await viewModel.ensurePostLoaded(id: postId)
            if loaded {
                navigationPath.append(FeedPostDestination(postId: postId, mediaIndex: 0))
            }
            onPendingPostHandled?()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: FeedScrollLock.notification)
        ) { notification in
            feedScrollLocked = notification.userInfo?["locked"] as? Bool ?? false
        }
        .onChange(of: isTabActive) { active in
            if !active {
                videoCoordinator.suspendPlayback()
            }
        }
        .onChange(of: selectedSegment) { segment in
            feedSegmentScrollState.reset()
            tabBarScrollState?.reset()
            if segment != .feed {
                videoCoordinator.suspendPlayback()
            }
        }
        .environment(\.feedTabIsActive, isTabActive && selectedSegment == .feed)
        .sheet(item: $profileRoute) { route in
            if let profileDependencies {
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(user: route.user)
                )
            }
        }
        .sheet(item: $companionsRoute) { route in
            CompanionsListSheet(companions: route.companions) { user in
                companionsRoute = nil
                openProfile(for: user)
            }
        }
    }

    @ViewBuilder
    private var feedPane: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: languageService.text(.feedLoading))
                .feedPagerPageTopInset(isEnabled: true)

        case .loaded(let posts) where posts.isEmpty:
            EmptyStateView(
                icon: "photo.on.rectangle.angled",
                title: languageService.text(.feedEmptyTitle),
                message: languageService.text(.feedEmptyMessage),
                actionTitle: languageService.text(.feedEmptyAction)
            ) {
                openPostCaptureFlow?()
            }
            .feedPagerPageTopInset(isEnabled: true)

        case .loaded:
            feedList

        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.loadFeed() }
            }
            .feedPagerPageTopInset(isEnabled: true)
        }
    }

    private var feedList: some View {
        FeedPullToRefreshScrollView(
            isRefreshing: Binding(
                get: { viewModel.isRefreshing },
                set: { _ in }
            )
        ) {
            FeedScrollLock.forceUnlock()
            feedScrollLocked = false
            defer {
                tabBarScrollState?.reset()
                feedSegmentScrollState.reset()
                viewModel.endRefreshingIfNeeded()
            }
            return await viewModel.loadFeed(isPullToRefresh: true)
        } content: {
            LazyVStack(spacing: SplickTheme.Spacing.md) {
                ForEach(viewModel.posts) { post in
                    PostCardView(
                        post: post,
                        currentUser: viewModel.currentUser,
                        onReact: { emoji in
                            if let error = viewModel.react(to: post.id, emoji: emoji) {
                                viewModel.alertMessage = error
                            }
                        },
                        onDelete: {
                            Task { await viewModel.deletePost(id: post.id) }
                        },
                        onUserTap: { user in
                            openProfile(for: user)
                        },
                        onOpenComments: {
                            guard viewModel.postUploadState(for: post.id) == nil else { return }
                            navigationPath.append(
                                FeedPostDestination(postId: post.id, mediaIndex: 0)
                            )
                        },
                        onShowCompanions: {
                            companionsRoute = CompanionsSheetRoute(
                                id: post.id,
                                companions: post.companions
                            )
                        },
                        onOpenDetail: { mediaIndex in
                            guard viewModel.postUploadState(for: post.id) == nil else { return }
                            navigationPath.append(
                                FeedPostDestination(postId: post.id, mediaIndex: mediaIndex)
                            )
                        },
                        onSendBillReminder: { postId, targetUserIds, message in
                            try await viewModel.sendBillReminder(
                                postId: postId,
                                targetUserIds: targetUserIds,
                                message: message
                            )
                        },
                        uploadState: viewModel.postUploadState(for: post.id)
                    )
                    .onAppear {
                        guard !viewModel.isRefreshing else { return }
                        Task { await viewModel.trackViewOnScrollIfNeeded(for: post) }
                        if post.id == viewModel.posts.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
        .scrollDisabled(feedScrollLocked)
        .environment(\.feedVideoCoordinator, videoCoordinator)
        .tabBarHideOnScroll()
    }

    private func openProfile(for user: UserSummary) {
        guard user.id != currentUserSummary?.id else { return }
        profileRoute = ProfileRoute(user: user)
    }
}
