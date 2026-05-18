import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var state: LoadingState<[Post]> = .idle
    @Published var isLoadingMore = false
    @Published private(set) var isRefreshing = false
    @Published var alertMessage: String?
    let currentUserId: UUID?
    var currentUser: UserSummary? { currentUserSummary }

    private let fetchFeedUseCase: FetchFeedUseCaseProtocol
    private let reactToPostUseCase: ReactToPostUseCaseProtocol
    private let deletePostUseCase: DeletePostUseCaseProtocol
    private var currentPage = 0
    private var canLoadMore = true

    private let currentUserSummary: UserSummary?

    public init(
        fetchFeedUseCase: FetchFeedUseCaseProtocol,
        reactToPostUseCase: ReactToPostUseCaseProtocol,
        deletePostUseCase: DeletePostUseCaseProtocol,
        currentUserId: UUID? = nil,
        currentUser: UserSummary? = nil
    ) {
        self.fetchFeedUseCase = fetchFeedUseCase
        self.reactToPostUseCase = reactToPostUseCase
        self.deletePostUseCase = deletePostUseCase
        self.currentUserId = currentUserId
        self.currentUserSummary = currentUser
    }

    func loadFeed(isPullToRefresh: Bool = false) async {
        if isPullToRefresh {
            guard !isRefreshing else { return }
            isRefreshing = true
        } else {
            state = .loading
        }

        isLoadingMore = false
        currentPage = 0
        canLoadMore = true

        do {
            let posts = try await fetchFeedUseCase.execute(page: 0)
            self.posts = posts
            state = .loaded(posts)
            canLoadMore = !posts.isEmpty
        } catch {
            if isPullToRefresh, !posts.isEmpty {
                state = .loaded(posts)
            } else {
                state = .failed(error.localizedDescription)
            }
            Log.error(error, category: .feed)
        }

        isRefreshing = false
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isRefreshing else { return }

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

    @discardableResult
    func react(to postId: UUID, emoji: String) async -> String? {
        guard let userId = currentUserId else { return nil }
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return nil }

        let post = posts[index]
        let distinctEmojis = Set(
            post.reactions.filter { $0.userId == userId }.map(\.emoji)
        )
        if !distinctEmojis.contains(emoji), distinctEmojis.count >= 5 {
            return "Mỗi bài bạn chỉ được dùng tối đa 5 loại emoji."
        }

        let reaction = Reaction(id: UUID(), emoji: emoji, userId: userId)
        posts[index] = post.updating(reactions: post.reactions + [reaction])
        state = .loaded(posts)

        do {
            _ = try await reactToPostUseCase.execute(postId: postId, emoji: emoji)
        } catch {
            posts[index] = post
            state = .loaded(posts)
            Log.error(error, category: .feed)
            return error.localizedDescription
        }
        return nil
    }

    @discardableResult
    func addComment(
        to postId: UUID,
        text: String,
        attachments: [CommentAttachment],
        parentCommentId: UUID? = nil
    ) async -> String? {
        guard let author = currentUserSummary else { return nil }

        if let error = CommentAttachmentValidator.validate(attachments) {
            return error
        }

        let comment = PostComment(
            author: author,
            text: text.isEmpty ? nil : text,
            attachments: attachments,
            parentCommentId: parentCommentId
        )

        if let index = posts.firstIndex(where: { $0.id == postId }) {
            let post = posts[index]
            posts[index] = post.updating(comments: post.comments + [comment])
            state = .loaded(posts)
        }
        return nil
    }

    func deletePost(id: UUID) async {
        guard let post = posts.first(where: { $0.id == id }) else { return }

        guard post.canDelete else {
            alertMessage = "Không thể xóa vì đã có người xem bài viết."
            return
        }

        do {
            try await deletePostUseCase.execute(postId: id)
            posts.removeAll { $0.id == id }
            state = .loaded(posts)
        } catch {
            alertMessage = error.localizedDescription
            Log.error(error, category: .feed)
        }
    }
}
