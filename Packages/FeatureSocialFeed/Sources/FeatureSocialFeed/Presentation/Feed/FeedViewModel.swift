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
    private var loadFeedTask: Task<Bool, Never>?
    private var loadFeedGeneration = 0

    private var currentUserSummary: UserSummary?

    // MARK: - Reaction sync (optimistic UI → one API call per tap, serialized per post)

    private struct PendingReactionSend: Equatable {
        let emoji: String
        let optimisticId: UUID
    }

    private var pendingReactionSends: [UUID: [PendingReactionSend]] = [:]
    private var reactionSyncTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Debounced view tracking (scroll → one GET after idle)

    private var pendingViewPostId: UUID?
    private var viewTrackFlushTask: Task<Void, Never>?
    private static let viewTrackDebounceNanos: UInt64 = 1_200_000_000

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

    @discardableResult
    func loadFeed(isPullToRefresh: Bool = false) async -> Bool {
        if isPullToRefresh {
            // Supersede any in-flight feed fetch (initial load, prior refresh) to avoid duplicate GET /v1/feed.
            loadFeedTask?.cancel()
        } else if let existing = loadFeedTask {
            return await existing.value
        }

        loadFeedGeneration += 1
        let generation = loadFeedGeneration

        let task = Task<Bool, Never> { @MainActor in
            await performLoadFeed(isPullToRefresh: isPullToRefresh, generation: generation)
        }
        loadFeedTask = task
        let succeeded = await task.value
        if generation == loadFeedGeneration {
            loadFeedTask = nil
        }
        return succeeded
    }

    /// Ensures refresh UI never stays stuck if a task was cancelled mid-flight.
    func endRefreshingIfNeeded() {
        isRefreshing = false
    }

    @discardableResult
    private func performLoadFeed(isPullToRefresh: Bool, generation: Int) async -> Bool {
        if isPullToRefresh {
            isRefreshing = true
            cancelViewTrackFlush()
        } else if posts.isEmpty {
            state = .loading
        }

        isLoadingMore = false
        currentPage = 0
        canLoadMore = true
        if !isPullToRefresh {
            trackedViewPostIds.removeAll()
        }

        defer {
            // Only clear when this request is still the latest refresh (avoids race when a prior pull was cancelled).
            if isPullToRefresh, generation == loadFeedGeneration {
                isRefreshing = false
            }
        }

        Log.info("Loading feed", category: .feed, metadata: ["pullToRefresh": String(isPullToRefresh)])

        do {
            let posts = try await fetchFeedUseCase.execute(page: 0)
            self.posts = posts
            state = .loaded(posts)
            canLoadMore = !posts.isEmpty
            Log.info("Loaded feed", category: .feed, metadata: ["count": String(posts.count)])
            return true
        } catch {
            if error.isRequestCancellation {
                return false
            }
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
            return false
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
            if error.isRequestCancellation { return }
            currentPage -= 1
            Log.error(error, category: .feed)
        }

        isLoadingMore = false
    }

    func refreshPost(id: UUID, preservingLocalComment localComment: PostComment? = nil) async {
        guard !isRefreshing else { return }

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
            if error.isRequestCancellation { return }
            Log.error(error, category: .feed)
        }
    }

    func trackViewOnScrollIfNeeded(for post: Post) async {
        guard !isRefreshing else { return }
        guard let currentUserId, currentUserId != post.author.id else { return }
        guard !trackedViewPostIds.contains(post.id) else { return }

        trackedViewPostIds.insert(post.id)
        pendingViewPostId = post.id
        scheduleViewTrackFlush()
    }

    private func scheduleViewTrackFlush() {
        viewTrackFlushTask?.cancel()
        viewTrackFlushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.viewTrackDebounceNanos)
            guard !Task.isCancelled else { return }
            guard !isRefreshing, let postId = pendingViewPostId else { return }
            pendingViewPostId = nil
            await refreshPost(id: postId)
        }
    }

    private func cancelViewTrackFlush() {
        viewTrackFlushTask?.cancel()
        viewTrackFlushTask = nil
        pendingViewPostId = nil
    }

    private func matchesComment(_ lhs: PostComment, _ rhs: PostComment) -> Bool {
        lhs.author.id == rhs.author.id
            && lhs.text == rhs.text
            && lhs.parentCommentId == rhs.parentCommentId
    }

    @discardableResult
    func react(to postId: UUID, emoji: String) -> String? {
        guard let userId = currentUserId else { return nil }
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return nil }

        let post = posts[index]
        let distinctEmojis = Set(
            post.reactions.filter { $0.userId == userId }.map(\.emoji)
        )
        if !distinctEmojis.contains(emoji), distinctEmojis.count >= 5 {
            return "Mỗi bài bạn chỉ được dùng tối đa 5 loại emoji."
        }

        let optimisticId = UUID()
        let reaction = Reaction(id: optimisticId, emoji: emoji, userId: userId)
        posts[index] = post.updating(reactions: post.reactions + [reaction])

        pendingReactionSends[postId, default: []].append(
            PendingReactionSend(emoji: emoji, optimisticId: optimisticId)
        )
        startReactionSyncIfNeeded(for: postId)
        return nil
    }

    private func startReactionSyncIfNeeded(for postId: UUID) {
        guard reactionSyncTasks[postId] == nil else { return }
        reactionSyncTasks[postId] = Task { @MainActor in
            await processReactionQueue(for: postId)
            reactionSyncTasks[postId] = nil
            if !(pendingReactionSends[postId]?.isEmpty ?? true) {
                startReactionSyncIfNeeded(for: postId)
            }
        }
    }

    private func processReactionQueue(for postId: UUID) async {
        while let pending = pendingReactionSends[postId]?.first {
            pendingReactionSends[postId]?.removeFirst()
            if pendingReactionSends[postId]?.isEmpty == true {
                pendingReactionSends[postId] = nil
            }

            do {
                let serverReaction = try await reactToPostUseCase.execute(
                    postId: postId,
                    emoji: pending.emoji
                )
                reconcileReaction(
                    postId: postId,
                    optimisticId: pending.optimisticId,
                    with: serverReaction
                )
            } catch {
                removeReaction(postId: postId, reactionId: pending.optimisticId)
                Log.error(error, category: .feed)
                alertMessage = error.localizedDescription
            }
        }
    }

    private func reconcileReaction(postId: UUID, optimisticId: UUID, with server: Reaction) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        let post = posts[index]
        let reactions = post.reactions.map { reaction in
            reaction.id == optimisticId ? server : reaction
        }
        posts[index] = post.updating(reactions: reactions)
    }

    private func removeReaction(postId: UUID, reactionId: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        let post = posts[index]
        posts[index] = post.updating(
            reactions: post.reactions.filter { $0.id != reactionId }
        )
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
