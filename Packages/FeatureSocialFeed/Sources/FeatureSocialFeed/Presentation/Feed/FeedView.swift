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
    private let photoAlbumViewModel: PhotoAlbumViewModel
    @State private var profileRoute: ProfileRoute?
    @State private var companionsRoute: CompanionsSheetRoute?
    @State private var feedScrollLocked = false
    @StateObject private var videoCoordinator = FeedVideoPlaybackCoordinator()

    public init(
        viewModel: FeedViewModel,
        photoAlbumViewModel: PhotoAlbumViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol? = nil,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol? = nil,
        navigationPath: Binding<NavigationPath> = .constant(NavigationPath()),
        pendingPostId: UUID? = nil,
        onPendingPostHandled: (() -> Void)? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.photoAlbumViewModel = photoAlbumViewModel
        _navigationPath = navigationPath
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.pendingPostId = pendingPostId
        self.onPendingPostHandled = onPendingPostHandled
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: languageService.text(.feedLoading))

                case .loaded(let posts) where posts.isEmpty:
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: languageService.text(.feedEmptyTitle),
                        message: languageService.text(.feedEmptyMessage),
                        actionTitle: languageService.text(.feedEmptyAction)
                    ) {
                        openPostCaptureFlow?()
                    }

                case .loaded:
                    feedList

                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.loadFeed() }
                    }
                }
            }
            .navigationTitle(languageService.text(.feedTitle))
            .splickProfileToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: PhotoAlbumRoute()) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .accessibilityLabel(languageService.text(.feedPhotoAlbumAccessibility))
                }
            }
            .navigationDestination(for: PhotoAlbumRoute.self) { _ in
                PhotoAlbumView(
                    viewModel: photoAlbumViewModel,
                    feedViewModel: viewModel,
                    navigationPath: $navigationPath,
                    fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                    fetchMyGroupsUseCase: fetchMyGroupsUseCase
                )
            }
            .navigationDestination(for: FeedPostDestination.self) { destination in
                if let post = viewModel.posts.first(where: { $0.id == destination.postId }) {
                    PostDetailView(
                        post: post,
                        initialMediaIndex: destination.mediaIndex,
                        feedViewModel: viewModel,
                        fetchFriendsUseCase: fetchFriendsUseCase
                    )
                }
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
        .sheet(item: $profileRoute) { route in
            UserProfileView(user: route.user)
        }
        .sheet(item: $companionsRoute) { route in
            CompanionsListSheet(companions: route.companions) { user in
                companionsRoute = nil
                profileRoute = ProfileRoute(user: user)
            }
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
                            profileRoute = ProfileRoute(user: user)
                        },
                        onOpenComments: {
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
                            navigationPath.append(
                                FeedPostDestination(postId: post.id, mediaIndex: mediaIndex)
                            )
                        }
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
}
