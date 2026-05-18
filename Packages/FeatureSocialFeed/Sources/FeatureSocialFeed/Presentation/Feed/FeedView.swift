import SwiftUI
import DesignSystem
import Common
import SplickDomain

private struct ProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}

public struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    @State private var profileRoute: ProfileRoute?
    @State private var companionsRoute: CompanionsSheetRoute?
    @State private var feedScrollLocked = false
    @StateObject private var videoCoordinator = FeedVideoPlaybackCoordinator()

    public init(
        viewModel: @autoclosure @escaping () -> FeedViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.fetchFriendsUseCase = fetchFriendsUseCase
    }

    public var body: some View {
        NavigationStack {
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
                    ) {}

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
            .navigationDestination(for: UUID.self) { postId in
                if let post = viewModel.posts.first(where: { $0.id == postId }) {
                    PostDetailView(
                        post: post,
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
            Task { await viewModel.loadFeed() }
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
        ScrollView {
            LazyVStack(spacing: SplickTheme.Spacing.md) {
                ForEach(viewModel.posts) { post in
                    PostCardView(
                        post: post,
                        currentUser: viewModel.currentUser,
                        onReact: { emoji in
                            Task {
                                if let error = await viewModel.react(to: post.id, emoji: emoji) {
                                    viewModel.alertMessage = error
                                }
                            }
                        },
                        onDelete: {
                            Task { await viewModel.deletePost(id: post.id) }
                        },
                        onUserTap: { user in
                            profileRoute = ProfileRoute(user: user)
                        },
                        onOpenComments: {},
                        onShowCompanions: {
                            companionsRoute = CompanionsSheetRoute(
                                id: post.id,
                                companions: post.companions
                            )
                        }
                    )
                    .onAppear {
                        guard !viewModel.isRefreshing else { return }
                        if post.id == viewModel.posts.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
        .scrollDisabled(feedScrollLocked)
        .refreshable { await viewModel.loadFeed(isPullToRefresh: true) }
        .environment(\.feedVideoCoordinator, videoCoordinator)
        .tabBarHideOnScroll()
    }
}
