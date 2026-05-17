import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var state: LoadingState<[Post]> = .idle
    @Published var isLoadingMore = false

    private let fetchFeedUseCase: FetchFeedUseCaseProtocol
    private let reactToPostUseCase: ReactToPostUseCaseProtocol
    private var currentPage = 0
    private var canLoadMore = true

    public init(
        fetchFeedUseCase: FetchFeedUseCaseProtocol,
        reactToPostUseCase: ReactToPostUseCaseProtocol
    ) {
        self.fetchFeedUseCase = fetchFeedUseCase
        self.reactToPostUseCase = reactToPostUseCase
    }

    func loadFeed() async {
        state = .loading
        currentPage = 0
        canLoadMore = true

        do {
            let posts = try await fetchFeedUseCase.execute(page: 0)
            self.posts = posts
            state = .loaded(posts)
            canLoadMore = !posts.isEmpty
        } catch {
            state = .failed(error.localizedDescription)
            Log.error(error, category: .feed)
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }

        isLoadingMore = true
        currentPage += 1

        do {
            let newPosts = try await fetchFeedUseCase.execute(page: currentPage)
            posts.append(contentsOf: newPosts)
            canLoadMore = !newPosts.isEmpty
            state = .loaded(posts)
        } catch {
            currentPage -= 1
            Log.error(error, category: .feed)
        }

        isLoadingMore = false
    }

    func react(to postId: UUID, emoji: String) async {
        do {
            let reaction = try await reactToPostUseCase.execute(postId: postId, emoji: emoji)
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let post = posts[index]
                let updatedReactions = post.reactions + [reaction]
                posts[index] = Post(
                    id: post.id,
                    author: post.author,
                    imageURL: post.imageURL,
                    thumbnailURL: post.thumbnailURL,
                    caption: post.caption,
                    reactions: updatedReactions,
                    groupId: post.groupId,
                    createdAt: post.createdAt
                )
            }
        } catch {
            Log.error(error, category: .feed)
        }
    }
}
