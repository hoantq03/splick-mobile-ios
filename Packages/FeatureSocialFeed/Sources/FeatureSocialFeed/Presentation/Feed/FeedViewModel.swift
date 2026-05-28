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
    private(set) var currentUserId: UUID?
    var currentUser: UserSummary? { currentUserSummary }

    private let fetchFeedUseCase: FetchFeedUseCaseProtocol
    private let fetchPostUseCase: FetchPostUseCaseProtocol
    private let reactToPostUseCase: ReactToPostUseCaseProtocol
    private let deletePostUseCase: DeletePostUseCaseProtocol
    private let addCommentUseCase: AddCommentUseCaseProtocol
    private var currentPage = 0
    private var canLoadMore = true
    private var trackedViewPostIds = Set<UUID>()

    private var currentUserSummary: UserSummary?

    public init(
        fetchFeedUseCase: FetchFeedUseCaseProtocol,
        fetchPostUseCase: FetchPostUseCaseProtocol,
        reactToPostUseCase: ReactToPostUseCaseProtocol,
        deletePostUseCase: DeletePostUseCaseProtocol,
        addCommentUseCase: AddCommentUseCaseProtocol,
        currentUserId: UUID? = nil,
        currentUser: UserSummary? = nil
    ) {
        self.fetchFeedUseCase = fetchFeedUseCase
        self.fetchPostUseCase = fetchPostUseCase
        self.reactToPostUseCase = reactToPostUseCase
        self.deletePostUseCase = deletePostUseCase
        self.addCommentUseCase = addCommentUseCase
        self.currentUserId = currentUserId
        self.currentUserSummary = currentUser
    }

    func updateSession(user: UserSummary?, userId: UUID?) {
        currentUserSummary = user
        currentUserId = userId ?? user?.id
    }

    func loadFeed(isPullToRefresh: Bool = false) async {
        if isPullToRefresh {
            guard !isRefreshing else { return }
            isRefreshing = true
        } else if posts.isEmpty {
            state = .loading
        }

        isLoadingMore = false
        currentPage = 0
        canLoadMore = true
        trackedViewPostIds.removeAll()

        defer {
            if isPullToRefresh {
                isRefreshing = false
            }
        }

        do {
            let posts = try await fetchFeedUseCase.execute(page: 0)
            self.posts = posts
            state = .loaded(posts)
            canLoadMore = !posts.isEmpty
        } catch {
            Log.error(error, category: .feed)
            if isPullToRefresh {
                if posts.isEmpty {
                    state = .failed(error.localizedDescription)
                } else {
                    state = .loaded(posts)
                }
                alertMessage = "Không thể làm mới feed. Thử lại sau."
            } else if posts.isEmpty {
                state = .failed(error.localizedDescription)
            } else {
                state = .loaded(posts)
            }
        }
    }

    /// Show the new post immediately, then sync the first page from the server.
    public func syncFeedAfterCreatingPost(_ created: Post) async {
        prependCreatedPost(created)
        await loadFeed(isPullToRefresh: true)
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

    func refreshPost(id: UUID, preservingLocalComment localComment: PostComment? = nil) async {
        do {
            var updated = try await fetchPostUseCase.execute(postId: id)
            if let localComment,
               !updated.comments.contains(where: { matchesComment($0, localComment) }) {
                updated = updated.updating(comments: updated.comments + [localComment])
            }
            if let index = posts.firstIndex(where: { $0.id == id }) {
                posts[index] = updated
                state = .loaded(posts)
            }
        } catch {
            Log.error(error, category: .feed)
        }
    }

    func trackViewOnScrollIfNeeded(for post: Post) async {
        guard let currentUserId, currentUserId != post.author.id else { return }
        guard !trackedViewPostIds.contains(post.id) else { return }

        trackedViewPostIds.insert(post.id)
        await refreshPost(id: post.id)
    }

    private func matchesComment(_ lhs: PostComment, _ rhs: PostComment) -> Bool {
        lhs.author.id == rhs.author.id
            && lhs.text == rhs.text
            && lhs.parentCommentId == rhs.parentCommentId
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
        submissionAttachments: [CommentSubmissionAttachment],
        parentCommentId: UUID? = nil
    ) async -> String? {
        guard let author = currentUserSummary else {
            return "Không xác định được tài khoản. Hãy thử kéo refresh tab Feed."
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && submissionAttachments.isEmpty {
            return "Nội dung bình luận hoặc đính kèm không được để trống."
        }

        let comment = PostComment(
            author: author,
            text: trimmed.isEmpty ? nil : trimmed,
            attachments: [],
            parentCommentId: parentCommentId
        )

        guard let index = posts.firstIndex(where: { $0.id == postId }) else {
            return "Không tìm thấy bài viết."
        }

        let post = posts[index]
        posts[index] = post.updating(comments: post.comments + [comment])
        state = .loaded(posts)

        do {
            try await addCommentUseCase.execute(
                postId: postId,
                body: trimmed.isEmpty ? nil : trimmed,
                parentCommentId: parentCommentId,
                submissionAttachments: submissionAttachments
            )
            await refreshPost(id: postId, preservingLocalComment: comment)
        } catch {
            posts[index] = post
            state = .loaded(posts)
            Log.error(error, category: .feed)
            return error.localizedDescription
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

    /// Inserts a newly created post at the top of the feed (optimistic UI after create).
    public func prependCreatedPost(_ post: Post) {
        guard !posts.contains(where: { $0.id == post.id }) else { return }
        posts.insert(post, at: 0)
        state = .loaded(posts)
    }

    @discardableResult
    func ensurePostLoaded(id: UUID) async -> Bool {
        if posts.contains(where: { $0.id == id }) {
            return true
        }

        do {
            let post = try await fetchPostUseCase.execute(postId: id)
            posts.insert(post, at: 0)
            state = .loaded(posts)
            return true
        } catch {
            alertMessage = "Không thể tải bài viết."
            Log.error(error, category: .feed)
            return false
        }
    }
}
