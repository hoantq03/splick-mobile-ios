import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var state: LoadingState<[Post]> = .idle
    @Published var isLoadingMore = false
    @Published private(set) var hasReachedFeedEnd = false
    @Published private(set) var isRefreshing = false
    @Published var alertMessage: String?
    private(set) var currentUserId: UUID?
    var currentUser: UserSummary? { currentUserSummary }

    private let fetchFeedUseCase: FetchFeedUseCaseProtocol
    private let fetchPostUseCase: FetchPostUseCaseProtocol
    private let reactToPostUseCase: ReactToPostUseCaseProtocol
    private let deletePostUseCase: DeletePostUseCaseProtocol
    private let addCommentUseCase: AddCommentUseCaseProtocol
    private let sendBillReminderUseCase: SendBillReminderUseCaseProtocol
    private let submitPaymentEvidenceUseCase: SubmitPaymentEvidenceUseCaseProtocol
    private let approvePaymentEvidenceUseCase: ApprovePaymentEvidenceUseCaseProtocol
    private let rejectPaymentEvidenceUseCase: RejectPaymentEvidenceUseCaseProtocol
    private let createPostUseCase: CreatePostUseCaseProtocol
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

    /// Optimistic comment ids not yet confirmed by the server — block reply to avoid invalid parent ids.
    private var pendingCommentIds = Set<UUID>()

    // MARK: - Lazy post upload (optimistic feed card → background upload)

    @Published private(set) var postUploadStates: [UUID: PostUploadState] = [:]
    private var postUploadTasks: [UUID: Task<Void, Never>] = [:]

    public init(
        fetchFeedUseCase: FetchFeedUseCaseProtocol,
        fetchPostUseCase: FetchPostUseCaseProtocol,
        reactToPostUseCase: ReactToPostUseCaseProtocol,
        deletePostUseCase: DeletePostUseCaseProtocol,
        addCommentUseCase: AddCommentUseCaseProtocol,
        sendBillReminderUseCase: SendBillReminderUseCaseProtocol,
        submitPaymentEvidenceUseCase: SubmitPaymentEvidenceUseCaseProtocol,
        approvePaymentEvidenceUseCase: ApprovePaymentEvidenceUseCaseProtocol,
        rejectPaymentEvidenceUseCase: RejectPaymentEvidenceUseCaseProtocol,
        createPostUseCase: CreatePostUseCaseProtocol,
        currentUserId: UUID? = nil,
        currentUser: UserSummary? = nil
    ) {
        self.fetchFeedUseCase = fetchFeedUseCase
        self.fetchPostUseCase = fetchPostUseCase
        self.reactToPostUseCase = reactToPostUseCase
        self.deletePostUseCase = deletePostUseCase
        self.addCommentUseCase = addCommentUseCase
        self.sendBillReminderUseCase = sendBillReminderUseCase
        self.submitPaymentEvidenceUseCase = submitPaymentEvidenceUseCase
        self.approvePaymentEvidenceUseCase = approvePaymentEvidenceUseCase
        self.rejectPaymentEvidenceUseCase = rejectPaymentEvidenceUseCase
        self.createPostUseCase = createPostUseCase
        self.currentUserId = currentUserId
        self.currentUserSummary = currentUser
    }

    public func postUploadState(for postId: UUID) -> PostUploadState? {
        postUploadStates[postId]
    }

    public var hasPendingPostUploads: Bool {
        !postUploadStates.isEmpty
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
        hasReachedFeedEnd = false
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
            self.posts = mergeFeedPreservingPendingUploads(with: posts)
            state = .loaded(self.posts)
            canLoadMore = !posts.isEmpty
            updateHasReachedFeedEnd()
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

    /// Inserts an optimistic post and uploads media + creates the post in the background.
    public func enqueuePostUpload(optimisticPost: Post, input: CreatePostInput) {
        let localPostId = optimisticPost.id
        prependCreatedPost(optimisticPost)
        postUploadStates[localPostId] = .uploading

        postUploadTasks[localPostId]?.cancel()
        postUploadTasks[localPostId] = Task { [weak self] in
            await self?.performBackgroundPostUpload(localPostId: localPostId, input: input)
        }
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
            updateHasReachedFeedEnd()
        } catch {
            if error.isRequestCancellation { return }
            currentPage -= 1
            Log.error(error, category: .feed)
        }

        isLoadingMore = false
    }

    private func updateHasReachedFeedEnd() {
        hasReachedFeedEnd = !canLoadMore && !posts.isEmpty
    }

    func refreshPost(id: UUID, allowingConcurrentFeedRefresh: Bool = false) async {
        if !allowingConcurrentFeedRefresh {
            guard !isRefreshing else { return }
        }

        do {
            let updated = try await fetchPostUseCase.execute(postId: id)
            if let index = posts.firstIndex(where: { $0.id == id }) {
                posts[index] = updated
                state = .loaded(posts)
            }
        } catch {
            if error.isRequestCancellation { return }
            Log.error(error, category: .feed)
        }
    }

    func canReply(to comment: PostComment) -> Bool {
        !pendingCommentIds.contains(comment.id)
    }

    func trackViewOnScrollIfNeeded(for post: Post) async {
        guard !isRefreshing else { return }
        guard postUploadStates[post.id] == nil else { return }
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
            && normalizedCommentBody(lhs.text) == normalizedCommentBody(rhs.text)
            && lhs.parentCommentId == rhs.parentCommentId
    }

    private func normalizedCommentBody(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolveCreatedCommentId(
        postId: UUID,
        authorId: UUID,
        text: String?,
        parentCommentId: UUID?,
        fallbackId: UUID
    ) -> UUID {
        guard let post = posts.first(where: { $0.id == postId }) else { return fallbackId }
        let normalizedText = normalizedCommentBody(text)
        let byAuthorAndBody = post.comments.filter {
            $0.author.id == authorId && normalizedCommentBody($0.text) == normalizedText
        }
        if let exact = byAuthorAndBody.first(where: { $0.parentCommentId == parentCommentId }) {
            return exact.id
        }
        if let latest = byAuthorAndBody.max(by: { $0.createdAt < $1.createdAt }) {
            return latest.id
        }
        return post.comments
            .filter { $0.author.id == authorId && $0.parentCommentId == parentCommentId }
            .max(by: { $0.createdAt < $1.createdAt })?
            .id ?? fallbackId
    }

    @discardableResult
    func react(to postId: UUID, emoji: String) -> String? {
        guard postUploadStates[postId] == nil else {
            return "Bài viết đang được đăng."
        }
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

    struct AddCommentResult: Equatable {
        let error: String?
        let createdCommentId: UUID?
    }

    @discardableResult
    func addComment(
        to postId: UUID,
        text: String,
        submissionAttachments: [CommentSubmissionAttachment],
        parentCommentId: UUID? = nil
    ) async -> AddCommentResult {
        guard let author = currentUserSummary else {
            return AddCommentResult(
                error: "Không xác định được tài khoản. Hãy thử kéo refresh tab Feed.",
                createdCommentId: nil
            )
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && submissionAttachments.isEmpty {
            return AddCommentResult(
                error: "Nội dung bình luận hoặc đính kèm không được để trống.",
                createdCommentId: nil
            )
        }

        let comment = PostComment(
            author: author,
            text: trimmed.isEmpty ? nil : trimmed,
            attachments: [],
            parentCommentId: parentCommentId
        )
        let optimisticId = comment.id

        guard let index = posts.firstIndex(where: { $0.id == postId }) else {
            return AddCommentResult(error: "Không tìm thấy bài viết.", createdCommentId: nil)
        }

        if postUploadStates[postId] != nil {
            return AddCommentResult(error: "Bài viết đang được đăng.", createdCommentId: nil)
        }

        let post = posts[index]
        pendingCommentIds.insert(optimisticId)
        posts[index] = post.updating(comments: post.comments + [comment])
        state = .loaded(posts)

        do {
            try await addCommentUseCase.execute(
                postId: postId,
                body: trimmed.isEmpty ? nil : trimmed,
                parentCommentId: parentCommentId,
                submissionAttachments: submissionAttachments
            )
            await refreshPost(id: postId, allowingConcurrentFeedRefresh: true)
            pendingCommentIds.remove(optimisticId)
            removeCommentFromPost(postId: postId, commentId: optimisticId)
            let resolvedId = resolveCreatedCommentId(
                postId: postId,
                authorId: author.id,
                text: comment.text,
                parentCommentId: parentCommentId,
                fallbackId: optimisticId
            )
            return AddCommentResult(error: nil, createdCommentId: resolvedId)
        } catch {
            pendingCommentIds.remove(optimisticId)
            posts[index] = post
            state = .loaded(posts)
            Log.error(error, category: .feed)
            return AddCommentResult(
                error: error.localizedDescription,
                createdCommentId: nil
            )
        }
    }

    private func removeCommentFromPost(postId: UUID, commentId: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        let post = posts[index]
        guard post.comments.contains(where: { $0.id == commentId }) else { return }
        posts[index] = post.updating(
            comments: post.comments.filter { $0.id != commentId }
        )
        state = .loaded(posts)
    }

    func deletePost(id: UUID) async {
        guard let post = posts.first(where: { $0.id == id }) else { return }

        if postUploadStates[id] != nil {
            cancelPendingPostUpload(postId: id)
            posts.removeAll { $0.id == id }
            state = .loaded(posts)
            return
        }

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

    private func performBackgroundPostUpload(localPostId: UUID, input: CreatePostInput) async {
        defer { postUploadTasks[localPostId] = nil }

        do {
            let serverPost = try await createPostUseCase.execute(input)
            replaceOptimisticPost(localId: localPostId, with: serverPost)
            postUploadStates.removeValue(forKey: localPostId)
            OptimisticPostBuilder.cleanupPendingMedia(postId: localPostId)
        } catch {
            if error.isRequestCancellation { return }
            postUploadStates[localPostId] = .failed(message: error.localizedDescription)
            Log.error(error, category: .feed)
            alertMessage = "Không thể đăng bài. Thử lại sau."
        }
    }

    private func replaceOptimisticPost(localId: UUID, with serverPost: Post) {
        if let index = posts.firstIndex(where: { $0.id == localId }) {
            posts[index] = serverPost
        } else {
            prependCreatedPost(serverPost)
        }
        state = .loaded(posts)
    }

    private func mergeFeedPreservingPendingUploads(with fetched: [Post]) -> [Post] {
        let pendingIds = Set(postUploadStates.keys)
        guard !pendingIds.isEmpty else { return fetched }

        let pendingPosts = posts.filter { pendingIds.contains($0.id) }
        let rest = fetched.filter { !pendingIds.contains($0.id) }
        return pendingPosts + rest
    }

    private func cancelPendingPostUpload(postId: UUID) {
        postUploadTasks[postId]?.cancel()
        postUploadTasks[postId] = nil
        postUploadStates.removeValue(forKey: postId)
        OptimisticPostBuilder.cleanupPendingMedia(postId: postId)
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

    func sendBillReminder(
        postId: UUID,
        targetUserIds: [UUID]?,
        message: String
    ) async throws -> SendBillReminderResult {
        try await sendBillReminderUseCase.execute(
            postId: postId,
            targetUserIds: targetUserIds,
            message: message
        )
    }

    func submitPaymentEvidence(
        postId: UUID,
        splitId: UUID,
        message: String?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws {
        _ = try await submitPaymentEvidenceUseCase.execute(
            postId: postId,
            splitId: splitId,
            message: message,
            submissionAttachments: submissionAttachments
        )
        await refreshPost(id: postId, allowingConcurrentFeedRefresh: true)
    }

    func canModerateEvidence(on comment: PostComment, post: Post) -> Bool {
        guard let currentUserId else { return false }
        guard post.author.id == currentUserId else { return false }
        guard comment.isEvidence, comment.evidenceStatus == .pending else { return false }
        return comment.evidenceId != nil
    }

    func approvePaymentEvidence(postId: UUID, evidenceId: UUID) async {
        do {
            try await approvePaymentEvidenceUseCase.execute(postId: postId, evidenceId: evidenceId)
            await refreshPost(id: postId, allowingConcurrentFeedRefresh: true)
        } catch {
            alertMessage = error.localizedDescription
            Log.error(error, category: .feed)
        }
    }

    func rejectPaymentEvidence(postId: UUID, evidenceId: UUID, reason: String) async {
        do {
            try await rejectPaymentEvidenceUseCase.execute(
                postId: postId,
                evidenceId: evidenceId,
                reason: reason
            )
            await refreshPost(id: postId, allowingConcurrentFeedRefresh: true)
        } catch {
            alertMessage = error.localizedDescription
            Log.error(error, category: .feed)
        }
    }
}
