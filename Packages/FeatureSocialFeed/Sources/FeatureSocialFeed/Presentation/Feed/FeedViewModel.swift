import Foundation
import SwiftUI
import Common
import Localization
import DesignSystem
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
    private let recordPostViewsUseCase: RecordPostViewsUseCaseProtocol?
    private let reactToPostUseCase: ReactToPostUseCaseProtocol
    private let deletePostUseCase: DeletePostUseCaseProtocol
    private let addCommentUseCase: AddCommentUseCaseProtocol
    private let sendBillReminderUseCase: SendBillReminderUseCaseProtocol
    private let submitPaymentEvidenceUseCase: SubmitPaymentEvidenceUseCaseProtocol
    private let approvePaymentEvidenceUseCase: ApprovePaymentEvidenceUseCaseProtocol
    private let rejectPaymentEvidenceUseCase: RejectPaymentEvidenceUseCaseProtocol
    private let createPostUseCase: CreatePostUseCaseProtocol
    private let feedRepository: FeedRepositoryProtocol?
    private let languageService: LanguageService
    private let onFeedLoaded: (([Post], UUID?) async -> Void)?
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

    // MARK: - Batched view tracking (scroll → one POST after idle)

    private var pendingViewPostIds = Set<UUID>()
    private var viewTrackFlushTask: Task<Void, Never>?
    private static let viewTrackDebounceNanos: UInt64 = 2_000_000_000

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
        languageService: LanguageService,
        recordPostViewsUseCase: RecordPostViewsUseCaseProtocol? = nil,
        feedRepository: FeedRepositoryProtocol? = nil,
        currentUserId: UUID? = nil,
        currentUser: UserSummary? = nil,
        onFeedLoaded: (([Post], UUID?) async -> Void)? = nil
    ) {
        self.fetchFeedUseCase = fetchFeedUseCase
        self.fetchPostUseCase = fetchPostUseCase
        self.recordPostViewsUseCase = recordPostViewsUseCase
        self.reactToPostUseCase = reactToPostUseCase
        self.deletePostUseCase = deletePostUseCase
        self.addCommentUseCase = addCommentUseCase
        self.sendBillReminderUseCase = sendBillReminderUseCase
        self.submitPaymentEvidenceUseCase = submitPaymentEvidenceUseCase
        self.approvePaymentEvidenceUseCase = approvePaymentEvidenceUseCase
        self.rejectPaymentEvidenceUseCase = rejectPaymentEvidenceUseCase
        self.createPostUseCase = createPostUseCase
        self.feedRepository = feedRepository
        self.languageService = languageService
        self.onFeedLoaded = onFeedLoaded
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

    public func applyStartupPosts(_ startupPosts: [Post]) {
        guard !startupPosts.isEmpty else { return }
        // Cancel any in-flight `GET /v1/feed` that raced startup.
        loadFeedTask?.cancel()
        loadFeedTask = nil
        posts = startupPosts
        state = .loaded(startupPosts)
        currentPage = 0
        canLoadMore = startupPosts.count >= 20
        hasReachedFeedEnd = startupPosts.count < 20
        prefetchImages(for: startupPosts)
        persistFeedCache()
    }

    /// Applies disk-cached feed posts when memory is empty (cold start before network).
    public func applyCachedPostsIfEmpty(_ cached: [Post]) {
        guard posts.isEmpty, !cached.isEmpty else { return }
        posts = cached
        state = .loaded(cached)
        currentPage = 0
        canLoadMore = cached.count >= 20
        hasReachedFeedEnd = false
        prefetchImages(for: cached)
    }

    /// Loads feed disk cache when posts are still empty (before/alongside startup).
    public func loadDiskCacheIfNeeded() async {
        guard posts.isEmpty, let userId = currentUserId, let feedRepository else { return }
        if let cached = await feedRepository.loadCachedFeed(userId: userId) {
            applyCachedPostsIfEmpty(cached)
        }
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
        let signpost = FeedSignposts.beginFeedLoad(pullToRefresh: isPullToRefresh)
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
            let mergeSignpost = FeedSignposts.beginFeedMerge()
            let companionNames = companionGroupNameIndex()
            let hydratedPosts = posts.map { preserveClientMetadata(on: $0, companionNames: companionNames) }
            self.posts = mergeFeedPreservingClientState(with: hydratedPosts)
            FeedSignposts.endFeedMerge(mergeSignpost)
            state = .loaded(self.posts)
            canLoadMore = !posts.isEmpty
            updateHasReachedFeedEnd()
            Log.info("Loaded feed", category: .feed, metadata: ["count": String(posts.count)])
            FeedSignposts.endFeedLoad(signpost, count: posts.count)
            prefetchImages(for: self.posts)
            persistFeedCache()
            await onFeedLoaded?(self.posts, currentUserId)
            return true
        } catch {
            FeedSignposts.endFeedLoad(signpost, count: 0)
            if error.isRequestCancellation {
                return false
            }
            Log.error(error, category: .feed)
            if isPullToRefresh {
                if posts.isEmpty {
                    state = .failed(languageService.localizedMessage(for: error))
                } else {
                    state = .loaded(posts)
                }
                alertMessage = languageService.text(.feedRefreshFailed)
            } else if posts.isEmpty {
                state = .failed(languageService.localizedMessage(for: error))
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
            markPostsLoaded()
            updateHasReachedFeedEnd()
            prefetchImages(for: newPosts)
            persistFeedCache()
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
            let previous = posts.first(where: { $0.id == id })
            let companionNames = companionGroupNameIndex()
            let updated = preserveClientMetadata(
                on: try await fetchPostUseCase.execute(postId: id),
                companionNames: companionNames
            )
            let merged = previous.map { updated.mergingBillReminderCounts(from: $0) } ?? updated
            replacePost(merged)
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
        pendingViewPostIds.insert(post.id)
        scheduleViewTrackFlush()
    }

    private func scheduleViewTrackFlush() {
        viewTrackFlushTask?.cancel()
        viewTrackFlushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.viewTrackDebounceNanos)
            guard !Task.isCancelled else { return }
            guard !isRefreshing else { return }
            let batch = Array(pendingViewPostIds.prefix(20))
            pendingViewPostIds.subtract(batch)
            guard !batch.isEmpty else { return }
            await flushViewTracking(postIds: batch)
            // Flush remainder if more accumulated while in-flight.
            if !pendingViewPostIds.isEmpty {
                scheduleViewTrackFlush()
            }
        }
    }

    private func flushViewTracking(postIds: [UUID]) async {
        if let recordPostViewsUseCase {
            do {
                let updated = try await recordPostViewsUseCase.execute(postIds: postIds)
                let companionNames = companionGroupNameIndex()
                for remote in updated {
                    let hydrated = preserveClientMetadata(on: remote, companionNames: companionNames)
                    if let previous = posts.first(where: { $0.id == hydrated.id }) {
                        replacePost(hydrated.mergingBillReminderCounts(from: previous))
                    } else {
                        replacePost(hydrated)
                    }
                }
                return
            } catch {
                if error.isRequestCancellation { return }
                Log.error(error, category: .feed)
                // Fall through to per-post refresh for the first id only (best-effort).
            }
        }

        if let first = postIds.first {
            await refreshPost(id: first)
        }
    }

    private func cancelViewTrackFlush() {
        viewTrackFlushTask?.cancel()
        viewTrackFlushTask = nil
        pendingViewPostIds.removeAll()
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
            return languageService.text(.feedPostStillUploading)
        }
        guard let userId = currentUserId else { return nil }
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return nil }

        let post = posts[index]
        let distinctEmojis = Set(
            post.reactions.filter { $0.userId == userId }.map(\.emoji)
        )
        if !distinctEmojis.contains(emoji), distinctEmojis.count >= ReactionConstants.maxDistinctEmojiPerUser {
            return languageService.text(.feedReactionEmojiLimit)
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
                alertMessage = languageService.localizedMessage(for: error)
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
        submissionAttachments: [CommentSubmissionAttachment] = [],
        parentCommentId: UUID? = nil
    ) async -> AddCommentResult {
        guard let author = currentUserSummary else {
            return AddCommentResult(
                error: languageService.text(.feedErrorAccountRefresh),
                createdCommentId: nil
            )
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && submissionAttachments.isEmpty {
            return AddCommentResult(
                error: languageService.text(.feedCommentEmpty),
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
            return AddCommentResult(error: languageService.text(.feedPostNotFound), createdCommentId: nil)
        }

        if postUploadStates[postId] != nil {
            return AddCommentResult(error: languageService.text(.feedPostStillUploading), createdCommentId: nil)
        }

        let post = posts[index]
        pendingCommentIds.insert(optimisticId)
        posts[index] = post.updating(comments: post.comments + [comment])
        markPostsLoaded()

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
            markPostsLoaded()
            Log.error(error, category: .feed)
            return AddCommentResult(
                error: languageService.localizedMessage(for: error),
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
        markPostsLoaded()
    }

    func deletePost(id: UUID) async {
        guard let post = posts.first(where: { $0.id == id }) else { return }

        if postUploadStates[id] != nil {
            cancelPendingPostUpload(postId: id)
            posts.removeAll { $0.id == id }
            markPostsLoaded()
            return
        }

        guard post.canDelete else {
            alertMessage = languageService.text(.feedPostDeleteHasViewers)
            return
        }

        do {
            try await deletePostUseCase.execute(postId: id)
            posts.removeAll { $0.id == id }
            markPostsLoaded()
        } catch {
            alertMessage = languageService.localizedMessage(for: error)
            Log.error(error, category: .feed)
        }
    }

    /// Inserts a newly created post at the top of the feed (optimistic UI after create).
    public func prependCreatedPost(_ post: Post) {
        guard !posts.contains(where: { $0.id == post.id }) else { return }
        posts.insert(post, at: 0)
        markPostsLoaded()
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
            postUploadStates[localPostId] = .failed(message: languageService.localizedMessage(for: error))
            Log.error(error, category: .feed)
            alertMessage = languageService.text(.feedCreateRetryFailed)
        }
    }

    private func replaceOptimisticPost(localId: UUID, with serverPost: Post) {
        let companionNames = companionGroupNameIndex()
        let resolvedServerPost = preserveClientMetadata(on: serverPost, companionNames: companionNames)
        if let index = posts.firstIndex(where: { $0.id == localId }) {
            posts[index] = resolvedServerPost
        } else {
            prependCreatedPost(resolvedServerPost)
            return
        }
        markPostsLoaded()
    }

    private func mergeFeedPreservingClientState(with fetched: [Post]) -> [Post] {
        let previousById = Dictionary(uniqueKeysWithValues: posts.map { ($0.id, $0) })
        let withReminderCounts = fetched.map { remote -> Post in
            guard let local = previousById[remote.id] else { return remote }
            return remote.mergingBillReminderCounts(from: local)
        }
        return mergeFeedPreservingPendingUploads(with: withReminderCounts)
    }

    private func mergeFeedPreservingPendingUploads(with fetched: [Post]) -> [Post] {
        let pendingIds = Set(postUploadStates.keys)
        guard !pendingIds.isEmpty else { return fetched }

        let pendingPosts = posts.filter { pendingIds.contains($0.id) }
        let rest = fetched.filter { !pendingIds.contains($0.id) }
        return pendingPosts + rest
    }

    private func companionGroupNameIndex() -> [UUID: String] {
        Dictionary(
            uniqueKeysWithValues: posts.compactMap { post in
                guard let name = post.companionGroupName else { return nil }
                return (post.id, name)
            }
        )
    }

    private func preserveClientMetadata(on post: Post, companionNames: [UUID: String]) -> Post {
        guard post.companionGroupName == nil,
              let companionGroupName = companionNames[post.id] else {
            return post
        }
        return post.updating(companionGroupName: companionGroupName)
    }

    /// Indexed single-post mutation — avoids rewriting `state` when already `.loaded`.
    private func replacePost(_ post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
        markPostsLoaded()
    }

    private func markPostsLoaded() {
        // Keep LoadingState in sync for empty/non-empty transitions; skip redundant
        // associated-value rewrites while the list is already showing posts.
        if case .loaded(let existing) = state, !existing.isEmpty, !posts.isEmpty {
            return
        }
        state = .loaded(posts)
    }

    private func prefetchImages(for posts: [Post]) {
        var urls: [URL] = []
        urls.reserveCapacity(posts.count * 2)
        for post in posts {
            if let thumb = post.thumbnailURL {
                urls.append(thumb)
            } else if let first = post.displayMediaItems.first {
                urls.append(first.thumbnailURL ?? first.mediaURL)
            } else {
                urls.append(post.imageURL)
            }
            if let avatar = post.author.avatarURL {
                urls.append(avatar)
            }
        }
        ImagePrefetching.prefetch(
            urls: urls,
            thumbnailWidth: FeedMediaLayout.decodeMaxPixelSide
        )
    }

    private func persistFeedCache() {
        guard let userId = currentUserId, let feedRepository else { return }
        let snapshot = posts
        Task {
            await feedRepository.saveCachedFeed(snapshot, userId: userId)
        }
    }

    private func cancelPendingPostUpload(postId: UUID) {
        postUploadTasks[postId]?.cancel()
        postUploadTasks[postId] = nil
        postUploadStates.removeValue(forKey: postId)
        OptimisticPostBuilder.cleanupPendingMedia(postId: postId)
    }

    public enum PostLoadResult: Equatable {
        case loaded
        case unavailable
        case failed
    }

    @discardableResult
    public func ensurePostLoaded(id: UUID) async -> PostLoadResult {
        if posts.contains(where: { $0.id == id }) {
            return .loaded
        }

        do {
            let post = try await fetchPostUseCase.execute(postId: id)
            posts.insert(post, at: 0)
            markPostsLoaded()
            return .loaded
        } catch {
            let unavailable = Self.isPostUnavailable(error)
            alertMessage = unavailable
                ? languageService.text(.feedPostUnavailableMessage)
                : languageService.text(.feedPostLoadFailed)
            Log.error(error, category: .feed)
            return unavailable ? .unavailable : .failed
        }
    }

    private static func isPostUnavailable(_ error: Error) -> Bool {
        if let network = error as? NetworkError {
            switch network {
            case .forbidden, .notFound:
                return true
            case .apiError(_, let message, _), .unknown(let message, _):
                return messageSuggestsUnavailablePost(message)
            default:
                return false
            }
        }
        if let app = error as? AppError, case .network(let network) = app {
            return isPostUnavailable(network)
        }
        return messageSuggestsUnavailablePost(error.localizedDescription)
    }

    private static func messageSuggestsUnavailablePost(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("cannot access")
            || lowered.contains("forbidden")
            || lowered.contains("not found")
            || lowered.contains("deleted")
            || lowered.contains("không còn")
            || lowered.contains("không có quyền")
    }

    func sendBillReminder(
        postId: UUID,
        targetUserIds: [UUID]?,
        message: String,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SendBillReminderResult {
        let result = try await sendBillReminderUseCase.execute(
            postId: postId,
            targetUserIds: targetUserIds,
            message: message,
            submissionAttachments: submissionAttachments
        )

        guard let index = posts.firstIndex(where: { $0.id == postId }) else {
            return result
        }

        let post = posts[index]
        let targets: Set<UUID>
        if let targetUserIds, !targetUserIds.isEmpty {
            targets = Set(targetUserIds)
        } else {
            targets = Set(post.billSplit?.splits.filter { !$0.isPaid }.map(\.user.id) ?? [])
        }

        let optimistic = post.incrementingBillReminders(for: targets)
        posts[index] = optimistic
        markPostsLoaded()

        await refreshPost(id: postId, allowingConcurrentFeedRefresh: true)

        // Keep optimistic counts if the server payload is still missing reminderCount.
        if let refreshedIndex = posts.firstIndex(where: { $0.id == postId }) {
            posts[refreshedIndex] = posts[refreshedIndex].mergingBillReminderCounts(from: optimistic)
            markPostsLoaded()
        }

        return result
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
        NotificationCenter.default.post(name: .paymentEvidenceStatusDidChange, object: nil)
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
            NotificationCenter.default.post(name: .paymentEvidenceStatusDidChange, object: nil)
        } catch {
            alertMessage = languageService.localizedMessage(for: error)
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
            NotificationCenter.default.post(name: .paymentEvidenceStatusDidChange, object: nil)
        } catch {
            alertMessage = languageService.localizedMessage(for: error)
            Log.error(error, category: .feed)
        }
    }
}
