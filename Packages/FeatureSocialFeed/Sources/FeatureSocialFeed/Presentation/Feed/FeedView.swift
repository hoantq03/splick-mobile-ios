import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel

    public init(viewModel: @autoclosure @escaping () -> FeedViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
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
            .navigationTitle("Feed")
            .refreshable { await viewModel.loadFeed() }
        }
        .onFirstAppear {
            Task { await viewModel.loadFeed() }
        }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: SplickTheme.Spacing.md) {
                ForEach(viewModel.posts) { post in
                    PostCardView(post: post) { emoji in
                        Task { await viewModel.react(to: post.id, emoji: emoji) }
                    }
                    .onAppear {
                        if post.id == viewModel.posts.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
    }
}
