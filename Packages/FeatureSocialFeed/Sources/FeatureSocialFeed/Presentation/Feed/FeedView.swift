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
                sameTabTapHandlingEnabled: sameTabTapHandlingEnabled && navigationPath.isEmpty
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
            .background(SplickTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("")
            .splickTabNavigationBarChrome()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !notificationsPresented {
                        FeedNavPills(
                            selection: $selectedSegment,
                            collapseProgress: feedSegmentScrollState.collapseProgress,
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
            .navigationDestination(for: FeedPostDestination.self) { destination in
                PostDetailContainerView(
                    destination: destination,
                    feedViewModel: viewModel,
                    fetchFriendsUseCase: fetchFriendsUseCase,
                    profileDependencies: profileDependencies,
                    makeGifPickerViewModel: makeGifPickerViewModel
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
            // Initial posts come from AppStartupCoordinator (`GET /v1/app/startup`).
            // Fallback load runs from bootstrap when startup leaves the feed empty.
        }
        .onChange(of: currentUserSummary?.id) { _ in
            viewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
        }
        .task(id: pendingFeedPostNavigation) {
            guard let navigation = pendingFeedPostNavigation else { return }
            let result = await viewModel.ensurePostLoaded(id: navigation.postId)
            if result == .loaded {
                navigationPath.append(
                    FeedPostDestination(
                        postId: navigation.postId,
                        mediaIndex: 0,
                        expandBillSplit: navigation.expandBillSplit
                    )
                )
            }
            onPendingPostHandled?()
        }
        .onChange(of: isTabActive) { active in
            if !active {
                videoCoordinator.suspendPlayback()
            }
        }
        .onChange(of: selectedSegment) { segment in
            Task { @MainActor in
                feedSegmentScrollState.reset()
                tabBarScrollState?.reset()
                if segment != .feed {
                    videoCoordinator.suspendPlayback()
                }
            }
        }
        .onChange(of: viewModel.state) { state in
            guard selectedSegment == .feed else { return }
            if case .loaded(let posts) = state, posts.isEmpty {
                Task { @MainActor in
                    tabBarScrollState?.show()
                    feedSegmentScrollState.reset()
                }
            }
        }
        .environment(\.feedTabIsActive, isTabActive && selectedSegment == .feed)
        .onReceive(sameTabTapPublisher) { _ in
            handleSameTabTap()
        }
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

    private func openProfile(for user: UserSummary) {
        guard user.id != currentUserSummary?.id else { return }
        profileRoute = ProfileRoute(user: user)
    }

    private func handleSameTabTap() {
        guard sameTabTapHandlingEnabled, isTabActive else { return }

        // Detail → root first (Instagram-style).
        if !navigationPath.isEmpty {
            navigationPath = NavigationPath()
            tabBarScrollState?.show()
            return
        }

        guard selectedSegment == .feed else { return }

        // NotificationCenter crosses UIHostingController boundaries reliably.
        if tabBarScrollState?.isAtTop ?? true {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Single path: hosted scroll view shows spinner and calls loadFeed.
            NotificationCenter.default.post(name: FeedSameTabNotification.refresh, object: nil)
        } else {
            NotificationCenter.default.post(name: FeedSameTabNotification.scrollToTop, object: nil)
            tabBarScrollState?.reset()
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
    @ObservedObject var viewModel: FeedViewModel
    @Binding var navigationPath: NavigationPath
    @Binding var companionsRoute: CompanionsSheetRoute?
    let videoCoordinator: FeedVideoPlaybackCoordinator
    let makeGifPickerViewModel: GifPickerViewModelFactory?
    let onOpenProfile: (UserSummary) -> Void

    @State private var feedScrollLocked = false

    var body: some View {
        feedPane
            .onReceive(
                NotificationCenter.default.publisher(for: FeedScrollLock.notification)
            ) { notification in
                feedScrollLocked = notification.userInfo?["locked"] as? Bool ?? false
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
        FeedPullToRefreshScrollView {
            FeedScrollLock.forceUnlock()
            feedScrollLocked = false
            defer {
                tabBarScrollState?.reset()
                feedSegmentScrollState?.reset()
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
                            onOpenProfile(user)
                        },
                        onOpenComments: {
                            guard viewModel.postUploadState(for: post.id) == nil else { return }
                            navigationPath.append(
                                FeedPostDestination(
                                    postId: post.id,
                                    mediaIndex: 0,
                                    focusComposerOnAppear: post.commentCount == 0
                                )
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
                        onSendBillReminder: { postId, targetUserIds, message, attachments in
                            try await viewModel.sendBillReminder(
                                postId: postId,
                                targetUserIds: targetUserIds,
                                message: message,
                                submissionAttachments: attachments
                            )
                        },
                        onSubmitPaymentEvidence: { postId, splitId, message, attachments in
                            try await viewModel.submitPaymentEvidence(
                                postId: postId,
                                splitId: splitId,
                                message: message,
                                submissionAttachments: attachments
                            )
                        },
                        makeGifPickerViewModel: makeGifPickerViewModel,
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

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.md)
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
        .feedVideoVisibilityHandling(coordinator: videoCoordinator)
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
