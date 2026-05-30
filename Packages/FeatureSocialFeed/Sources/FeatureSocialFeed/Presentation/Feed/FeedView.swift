import SwiftUI
import DesignSystem
import Common
import SplickDomain

private struct ProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}

public struct FeedView: View {
    @ObservedObject private var viewModel: FeedViewModel
    @Binding private var navigationPath: NavigationPath
    private let pendingPostId: UUID?
    private let onPendingPostHandled: (() -> Void)?
    @Environment(\.openPostCaptureFlow) private var openPostCaptureFlow
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
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
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol? = nil,
        navigationPath: Binding<NavigationPath> = .constant(NavigationPath()),
        pendingPostId: UUID? = nil,
        onPendingPostHandled: (() -> Void)? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.photoAlbumViewModel = photoAlbumViewModel
        _navigationPath = navigationPath
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.pendingPostId = pendingPostId
        self.onPendingPostHandled = onPendingPostHandled
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Loading your feed...")

                case .loaded(let posts) where posts.isEmpty:
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: "No Posts Yet",
                        message: "Share a moment with your friends to get started!",
                        actionTitle: "Take a Photo"
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
            .navigationTitle("Feeds")
            .splickProfileToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: PhotoAlbumRoute()) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .accessibilityLabel("Album ảnh")
                }
            }
            .navigationDestination(for: PhotoAlbumRoute.self) { _ in
                PhotoAlbumView(
                    viewModel: photoAlbumViewModel,
                    feedViewModel: viewModel,
                    navigationPath: $navigationPath,
                    fetchFriendsUseCase: fetchFriendsUseCase,
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
                "Thông báo",
                isPresented: Binding(
                    get: { viewModel.alertMessage != nil },
                    set: { if !$0 { viewModel.alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.alertMessage = nil }
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
