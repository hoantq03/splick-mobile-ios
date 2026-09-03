import Foundation
import SwiftUI
import Common
import Localization
import DesignSystem
import SplickDomain

public struct GuestInviteSharePayload: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let urls: [URL]
}

@MainActor
public final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var state: LoadingState<[Post]> = .idle
    @Published var isLoadingMore = false
    @Published private(set) var hasReachedFeedEnd = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var newPostsCount = 0
    @Published var alertMessage: String?
    @Published var pendingStreakDelete: PendingStreakDelete?
    private(set) var currentUserId: UUID?
    var currentUser: UserSummary? { currentUserSummary }

    private let fetchFeedUseCase: FetchFeedUseCaseProtocol
    private let fetchPostUseCase: FetchPostUseCaseProtocol
    private let recordPostViewsUseCase: RecordPostViewsUseCaseProtocol?
    private let reactToPostUseCase: ReactToPostUseCaseProtocol
    private let listPostReactionsUseCase: ListPostReactionsUseCaseProtocol?
    private let deletePostUseCase: DeletePostUseCaseProtocol
    private let updatePostUseCase: UpdatePostUseCaseProtocol
    private let fetchPostEditHistoryUseCase: FetchPostEditHistoryUseCaseProtocol
    private let addCommentUseCase: AddCommentUseCaseProtocol
    private let sendBillReminderUseCase: SendBillReminderUseCaseProtocol
    private let submitPaymentEvidenceUseCase: SubmitPaymentEvidenceUseCaseProtocol
    private let approvePaymentEvidenceUseCase: ApprovePaymentEvidenceUseCaseProtocol
    private let rejectPaymentEvidenceUseCase: RejectPaymentEvidenceUseCaseProtocol
    private let createPostUseCase: CreatePostUseCaseProtocol
    private let feedRepository: FeedRepositoryProtocol?
    private let friendDisplayNameStore: FriendDisplayNameStore?
    private let languageService: LanguageService
    private let onFeedLoaded: (([Post], UUID?) async -> Void)?
    private let onPostsMutated: (() async -> Void)?
    private var friendDisplayNameObserver: NSObjectProtocol?
    private var currentPage = 0
    private var canLoadMore = true
    private var trackedViewPostIds = Set<UUID>()
    private var loadFeedTask: Task<Bool, Never>?
    private var loadFeedGeneration = 0

    /// Published so feed cards re-render author-only chrome (view count) when session hydrates.
    @Published private var currentUserSummary: UserSummary?

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
    @Published private(set) var pendingCommentIds = Set<UUID>()

    // MARK: - Lazy post upload (optimistic feed card → background upload)

    @Published private(set) var postUploadStates: [UUID: PostUploadState] = [:]
    @Published var pendingGuestInviteShare: GuestInviteSharePayload?
    private var postUploadTasks: [UUID: Task<Void, Never>] = [:]

    /// O(1) lookup for post mutations — rebuilt on full-feed assign, patched on insert/remove.
    private var postIndexById: [UUID: Int] = [:]
    /// Cached companion group names — invalidated on full-feed replace.
    private var cachedCompanionGroupNames: [UUID: String] = [:]
    private var companionIndexDirty = true

    public init(
        fetchFeedUseCase: FetchFeedUseCaseProtocol,
        fetchPostUseCase: FetchPostUseCaseProtocol,
        reactToPostUseCase: ReactToPostUseCaseProtocol,
        deletePostUseCase: DeletePostUseCaseProtocol,
        updatePostUseCase: UpdatePostUseCaseProtocol,
        fetchPostEditHistoryUseCase: FetchPostEditHistoryUseCaseProtocol,
        addCommentUseCase: AddCommentUseCaseProtocol,
        sendBillReminderUseCase: SendBillReminderUseCaseProtocol,
        submitPaymentEvidenceUseCase: SubmitPaymentEvidenceUseCaseProtocol,
        approvePaymentEvidenceUseCase: ApprovePaymentEvidenceUseCaseProtocol,
        rejectPaymentEvidenceUseCase: RejectPaymentEvidenceUseCaseProtocol,
        createPostUseCase: CreatePostUseCaseProtocol,
        languageService: LanguageService,
        recordPostViewsUseCase: RecordPostViewsUseCaseProtocol? = nil,
        listPostReactionsUseCase: ListPostReactionsUseCaseProtocol? = nil,
        feedRepository: FeedRepositoryProtocol? = nil,
        friendDisplayNameStore: FriendDisplayNameStore? = nil,
        currentUserId: UUID? = nil,
        currentUser: UserSummary? = nil,
        onFeedLoaded: (([Post], UUID?) async -> Void)? = nil,
        onPostsMutated: (() async -> Void)? = nil
    ) {
        self.fetchFeedUseCase = fetchFeedUseCase
        self.fetchPostUseCase = fetchPostUseCase
        self.recordPostViewsUseCase = recordPostViewsUseCase
        self.reactToPostUseCase = reactToPostUseCase
        self.listPostReactionsUseCase = listPostReactionsUseCase
        self.deletePostUseCase = deletePostUseCase
        self.updatePostUseCase = updatePostUseCase
        self.fetchPostEditHistoryUseCase = fetchPostEditHistoryUseCase
        self.addCommentUseCase = addCommentUseCase
        self.sendBillReminderUseCase = sendBillReminderUseCase
        self.submitPaymentEvidenceUseCase = submitPaymentEvidenceUseCase
        self.approvePaymentEvidenceUseCase = approvePaymentEvidenceUseCase
        self.rejectPaymentEvidenceUseCase = rejectPaymentEvidenceUseCase
        self.createPostUseCase = createPostUseCase
        self.feedRepository = feedRepository
        self.friendDisplayNameStore = friendDisplayNameStore
        self.languageService = languageService
        self.onFeedLoaded = onFeedLoaded
        self.onPostsMutated = onPostsMutated
        self.currentUserId = currentUserId
        self.currentUserSummary = currentUser

        if friendDisplayNameStore != nil {
            friendDisplayNameObserver = NotificationCenter.default.addObserver(
                forName: FriendDisplayNameStore.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.reapplyFriendDisplayNames()
                }
            }
        }
    }

    deinit {
        if let friendDisplayNameObserver {
            NotificationCenter.default.removeObserver(friendDisplayNameObserver)
        }
    }

    public func postUploadState(for postId: UUID) -> PostUploadState? {
        postUploadStates[postId]
    }

    public var hasPendingPostUploads: Bool {
        !postUploadStates.isEmpty
    }

    func updateSession(user: UserSummary?, userId: UUID?) {
        let resolvedId = userId ?? user?.id
        guard currentUserSummary != user || currentUserId != resolvedId else { return }
        currentUserSummary = user
        currentUserId = resolvedId
    }

    public func applyStartupPosts(_ startupPosts: [Post]) {
        guard !startupPosts.isEmpty else { return }
        // Cancel any in-flight `GET /v1/feed` that raced startup.
        loadFeedTask?.cancel()
        loadFeedTask = nil
        assignPosts(startupPosts, preserveVersionsFrom: nil)
        state = .loaded(posts)
        currentPage = 0
        canLoadMore = startupPosts.count >= 20
        hasReachedFeedEnd = startupPosts.count < 20
        prefetchImages(for: posts)
        persistFeedCache()
    }

    /// Applies disk-cached feed posts when memory is empty (cold start before network).
    public func applyCachedPostsIfEmpty(_ cached: [Post]) {
        guard posts.isEmpty, !cached.isEmpty else { return }
        assignPosts(cached, preserveVersionsFrom: nil)
        state = .loaded(posts)
        currentPage = 0
        canLoadMore = cached.count >= 20
        hasReachedFeedEnd = false
        prefetchImages(for: posts)
    }

    /// Loads feed disk cache when posts are still empty (before/alongside startup).
    public func loadDiskCacheIfNeeded() async {
        guard posts.isEmpty else { return }
        let userId = currentUserId
        if let userId, let feedRepository, let cached = await feedRepository.loadCachedFeed(userId: userId) {
            applyCachedPostsIfEmpty(cached)
            return
        }
    }

    /// Loads cached posts first so offline launches never flash an empty error screen.
    public func loadFeedIfNeeded() async {
        await loadDiskCacheIfNeeded()
        guard posts.isEmpty else { return }
        await loadFeed()
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

    /// Polls for posts newer than the current feed head while the Feed tab is visible.
    func pollNewPostsWhileActive() async {
        while !Task.isCancelled {
            await pollAheadCountOnce()
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return
            }
        }
    }

    func revealNewPosts() {
        newPostsCount = 0
        NotificationCenter.default.post(name: FeedSameTabNotification.scrollToTop, object: nil)
        NotificationCenter.default.post(name: FeedSameTabNotification.refresh, object: nil)
    }

    func refreshNewPostsCountIfNeeded() async {
        await pollAheadCountOnce()
    }

    private func pollAheadCountOnce() async {
        guard !isRefreshing, let frontier = feedHeadFrontier(), let feedRepository else { return }
        do {
            let count = try await feedRepository.countFeedPostsAhead(
                afterCreatedAt: frontier.createdAt,
                afterId: frontier.id
            )
            newPostsCount = max(0, count)
        } catch {
            // Keep the last pill; polling is best-effort.
            Log.debug(
                "Feed ahead-count poll failed",
                category: .feed,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func feedHeadFrontier() -> Post? {
        posts.first { postUploadStates[$0.id] == nil }
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
            newPostsCount = 0
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
            let previousById = Dictionary(uniqueKeysWithValues: self.posts.map { ($0.id, $0) })
            let hydratedPosts = posts.map { preserveClientMetadata(on: $0, companionNames: companionNames) }
            let merged = mergeFeedPreservingClientState(with: hydratedPosts)
            assignPosts(
                merged.map { $0.ensuringVersion(relativeTo: previousById[$0.id]) },
                preserveVersionsFrom: nil
            )
            FeedSignposts.endFeedMerge(mergeSignpost)
            state = .loaded(self.posts)
            canLoadMore = !posts.isEmpty
            updateHasReachedFeedEnd()
            Log.info("Loaded feed", category: .feed, metadata: ["count": String(posts.count)])
            FeedSignposts.endFeedLoad(signpost, count: posts.count)
            prefetchImages(for: self.posts)
            persistFeedCache()
            await onFeedLoaded?(self.posts, currentUserId)
            newPostsCount = 0
            return true
        } catch {
            FeedSignposts.endFeedLoad(signpost, count: 0)
            if error.isRequestCancellation {
                // Avoid infinite skeleton/spinner when the latest request dies with an empty feed.
                if generation == loadFeedGeneration, posts.isEmpty, state.isLoading {
                    state = .idle
                }
                return false
            }
            Log.error(error, category: .feed)
            await loadDiskCacheIfNeeded()
            if !posts.isEmpty {
                state = .loaded(posts)
                if isPullToRefresh {
                    alertMessage = languageService.text(.feedRefreshFailed)
                }
                return false
            }
            if isPullToRefresh {
                state = .failed(languageService.localizedMessage(for: error))
                alertMessage = languageService.text(.feedRefreshFailed)
            } else {
                state = .failed(languageService.localizedMessage(for: error))
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
            let startIndex = posts.count
            posts.append(contentsOf: newPosts)
            for (offset, post) in newPosts.enumerated() {
                postIndexById[post.id] = startIndex + offset
                if let name = post.companionGroupName {
                    cachedCompanionGroupNames[post.id] = name
                }
            }
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
            let previous: Post? = indexOfPost(id: id).map { posts[$0] }
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

    func fetchPostComments(
        postId: UUID,
        page: Int,
        limit: Int,
        filter: CommentThreadFilter
    ) async throws -> CommentThreadPage {
        if let feedRepository {
            return try await feedRepository.fetchPostComments(
                postId: postId,
                page: page,
                limit: limit,
                filter: filter
            )
        }
        let comments = posts.first(where: { $0.id == postId })?.comments ?? []
        return CommentThreadPage.paging(from: comments, page: page, limit: limit, filter: filter)
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
                    if let index = indexOfPost(id: hydrated.id) {
                        replacePost(hydrated.mergingBillReminderCounts(from: posts[index]))
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
        prefersAttachments: Bool,
        fallbackId: UUID
    ) -> UUID {
        guard let index = indexOfPost(id: postId) else { return fallbackId }
        let comments = posts[index].comments
        let normalizedText = normalizedCommentBody(text)

        var candidates = comments.filter {
            $0.author.id == authorId && $0.parentCommentId == parentCommentId
        }

        if let normalizedText {
            let bodyMatched = candidates.filter { normalizedCommentBody($0.text) == normalizedText }
            if !bodyMatched.isEmpty {
                candidates = bodyMatched
            }
        } else if prefersAttachments {
            let withAttachments = candidates.filter { !$0.attachments.isEmpty }
            if !withAttachments.isEmpty {
                candidates = withAttachments
            } else {
                let emptyBody = candidates.filter { normalizedCommentBody($0.text) == nil }
                if !emptyBody.isEmpty {
                    candidates = emptyBody
                }
            }
        } else {
            let emptyBody = candidates.filter { normalizedCommentBody($0.text) == nil }
            if !emptyBody.isEmpty {
                candidates = emptyBody
            }
        }

        if let latest = candidates.max(by: { $0.createdAt < $1.createdAt }) {
            return latest.id
        }

        // Never fall back to a removed optimistic id if a newer author comment exists.
        return comments
            .filter { $0.author.id == authorId }
            .max(by: { $0.createdAt < $1.createdAt })?
            .id ?? fallbackId
    }

    @discardableResult
    func react(to postId: UUID, emoji: String) -> String? {
        guard postUploadStates[postId] == nil else {
            return languageService.text(.feedPostStillUploading)
        }
        guard let user = currentUserSummary else { return nil }
        guard let index = indexOfPost(id: postId) else { return nil }

        let post = posts[index]
        let optimisticId = UUID()
        posts[index] = post.applyingOptimisticReaction(
            emoji: emoji,
            reactionId: optimisticId,
            user: user
        )

        pendingReactionSends[postId, default: []].append(
            PendingReactionSend(emoji: emoji, optimisticId: optimisticId)
        )
        startReactionSyncIfNeeded(for: postId)
        return nil
    }

    func loadPostReactions(postId: UUID) async throws -> [UserReactionSummary] {
        if let listPostReactionsUseCase {
            return try await listPostReactionsUseCase.execute(postId: postId)
        }
        if let feedRepository {
            return try await feedRepository.fetchPostReactions(postId: postId)
        }
        guard let index = indexOfPost(id: postId) else { return [] }
        return posts[index].userReactionSummaries()
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
                removeReaction(
                    postId: postId,
                    reactionId: pending.optimisticId,
                    emoji: pending.emoji,
                    userId: currentUserId
                )
                Log.error(error, category: .feed)
                alertMessage = languageService.localizedMessage(for: error)
            }
        }
    }

    private func reconcileReaction(postId: UUID, optimisticId: UUID, with server: Reaction) {
        guard let index = indexOfPost(id: postId) else { return }
        let post = posts[index]
        // Compact payloads keep an empty reactions bag; only remap ids when rows are present.
        guard !post.reactions.isEmpty else { return }
        let reactions = post.reactions.map { reaction in
            reaction.id == optimisticId ? server : reaction
        }
        posts[index] = post.updating(reactions: reactions)
    }

    private func removeReaction(
        postId: UUID,
        reactionId: UUID,
        emoji: String,
        userId: UUID?
    ) {
        guard let index = indexOfPost(id: postId) else { return }
        let post = posts[index]
        if let userId {
            posts[index] = post.removingOptimisticReaction(
                reactionId: reactionId,
                emoji: emoji,
                userId: userId
            )
        } else {
            posts[index] = post.updating(
                reactions: post.reactions.filter { $0.id != reactionId }
            )
        }
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
            attachments: Self.optimisticAttachments(from: submissionAttachments),
            parentCommentId: parentCommentId
        )
        let optimisticId = comment.id

        guard let index = indexOfPost(id: postId) else {
            return AddCommentResult(error: languageService.text(.feedPostNotFound), createdCommentId: nil)
        }

        if postUploadStates[postId] != nil {
            return AddCommentResult(error: languageService.text(.feedPostStillUploading), createdCommentId: nil)
        }

        let post = posts[index]
        posts[index] = post.updating(comments: post.comments + [comment])
        pendingCommentIds.insert(optimisticId)
        markPostsLoaded()
        // Let the thread paint the optimistic frame (image/GIF skeleton) before the network wait.
        await Task.yield()

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
                prefersAttachments: !submissionAttachments.isEmpty,
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

    /// Local/remote frames shown immediately while the comment API finishes.
    private static func optimisticAttachments(
        from submissions: [CommentSubmissionAttachment]
    ) -> [CommentAttachment] {
        submissions.map { submission in
            CommentAttachment(
                id: submission.uploadedMediaId ?? UUID(),
                kind: submission.kind,
                url: submission.remoteURL,
                fileName: submission.fileName,
                thumbnailURL: submission.uploadedThumbnailURL,
                sizeBytes: submission.uploadedSizeBytes ?? submission.data?.count ?? 0
            )
        }
    }

    private func removeCommentFromPost(postId: UUID, commentId: UUID) {
        guard let index = indexOfPost(id: postId) else { return }
        let post = posts[index]
        guard post.comments.contains(where: { $0.id == commentId }) else { return }
        posts[index] = post.updating(
            comments: post.comments.filter { $0.id != commentId }
        )
        markPostsLoaded()
    }

    func requestDelete(id: UUID) async {
        guard let index = indexOfPost(id: id) else { return }
        let post = posts[index]

        if postUploadStates[id] != nil {
            await deletePost(id: id)
            return
        }

        guard post.canDelete else {
            alertMessage = languageService.text(.feedPostDeleteHasEvidence)
            return
        }

        if let streakDays = await streakDaysIfDeleteBreaks(post) {
            pendingStreakDelete = PendingStreakDelete(postId: id, streakDays: streakDays)
            return
        }

        await deletePost(id: id)
    }

    func confirmPendingStreakDelete() async {
        guard let pending = pendingStreakDelete else { return }
        pendingStreakDelete = nil
        await deletePost(id: pending.postId)
    }

    func dismissPendingStreakDelete() {
        pendingStreakDelete = nil
    }

    func deletePost(id: UUID) async {
        guard let index = indexOfPost(id: id) else { return }
        let post = posts[index]

        if postUploadStates[id] != nil {
            cancelPendingPostUpload(postId: id)
            posts.remove(at: index)
            rebuildPostIndex()
            cachedCompanionGroupNames.removeValue(forKey: id)
            markPostsLoaded()
            return
        }

        guard post.canDelete else {
            alertMessage = languageService.text(.feedPostDeleteHasEvidence)
            return
        }

        do {
            try await deletePostUseCase.execute(postId: id)
            if let currentIndex = indexOfPost(id: id) {
                posts.remove(at: currentIndex)
                rebuildPostIndex()
                cachedCompanionGroupNames.removeValue(forKey: id)
            }
            markPostsLoaded()
            await onPostsMutated?()
        } catch {
            alertMessage = languageService.localizedMessage(for: error)
            Log.error(error, category: .feed)
        }
    }

    private func streakDaysIfDeleteBreaks(_ post: Post) async -> Int? {
        guard let feedRepository else { return nil }
        return await DeleteStreakRisk.streakDaysIfDeleteBreaks(
            post: post,
            knownPosts: posts,
            fetchSummary: { try await feedRepository.fetchStreakSummary() },
            fetchDayPhotos: { try await feedRepository.fetchStreakDayPhotos(date: $0) }
        )
    }

    func updatePost(_ input: UpdatePostInput) async throws -> Post {
        let updated = try await updatePostUseCase.execute(input)
        replacePost(updated)
        return updated
    }

    func fetchPostEdits(postId: UUID) async throws -> [PostEditRevision] {
        try await fetchPostEditHistoryUseCase.execute(postId: postId)
    }

    /// Inserts a newly created post at the top of the feed (optimistic UI after create).
    public func prependCreatedPost(_ post: Post) {
        guard postIndexById[post.id] == nil else { return }
        posts.insert(post, at: 0)
        rebuildPostIndex()
        if let name = post.companionGroupName {
            cachedCompanionGroupNames[post.id] = name
        }
        markPostsLoaded()
    }

    private func performBackgroundPostUpload(localPostId: UUID, input: CreatePostInput) async {
        defer { postUploadTasks[localPostId] = nil }

        do {
            let serverPost = try await createPostUseCase.execute(input)
            replaceOptimisticPost(localId: localPostId, with: serverPost)
            postUploadStates.removeValue(forKey: localPostId)
            OptimisticPostBuilder.cleanupPendingMedia(postId: localPostId)
            presentGuestInviteShareIfNeeded(for: serverPost)
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
        if let index = indexOfPost(id: localId) {
            let previous = posts[index]
            posts[index] = resolvedServerPost.ensuringVersion(relativeTo: previous)
            postIndexById.removeValue(forKey: localId)
            postIndexById[resolvedServerPost.id] = index
            if localId != resolvedServerPost.id {
                cachedCompanionGroupNames.removeValue(forKey: localId)
            }
            if let name = posts[index].companionGroupName {
                cachedCompanionGroupNames[posts[index].id] = name
            }
        } else {
            prependCreatedPost(resolvedServerPost)
            return
        }
        markPostsLoaded()
    }

    private func presentGuestInviteShareIfNeeded(for post: Post) {
        guard let bill = post.billSplit else { return }
        let personalUrls: [URL] = bill.splits.compactMap { line in
            guard let raw = line.inviteUrl, let url = URL(string: raw) else { return nil }
            return url
        }
        let tableUrl = bill.tableInviteUrl.flatMap(URL.init(string:))
        // One guest: share their /b/{token}. Several guests: share /b/t/{token} so they pick a name.
        // Never concatenate both — copy/paste would include two links.
        let urls: [URL]
        if personalUrls.count == 1 {
            urls = personalUrls
        } else if let tableUrl {
            urls = [tableUrl]
        } else {
            urls = personalUrls
        }
        guard !urls.isEmpty else { return }
        pendingGuestInviteShare = GuestInviteSharePayload(
            message: languageService.text(.feedGuestInviteShareMessage),
            urls: urls
        )
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
        if !companionIndexDirty {
            return cachedCompanionGroupNames
        }
        cachedCompanionGroupNames = Dictionary(
            uniqueKeysWithValues: posts.compactMap { post in
                guard let name = post.companionGroupName else { return nil }
                return (post.id, name)
            }
        )
        companionIndexDirty = false
        return cachedCompanionGroupNames
    }

    private func preserveClientMetadata(on post: Post, companionNames: [UUID: String]) -> Post {
        guard post.companionGroupName == nil,
              let companionGroupName = companionNames[post.id] else {
            return post
        }
        return post.updating(companionGroupName: companionGroupName)
    }

    /// Indexed single-post mutation — skips publish when card content is unchanged.
    private func replacePost(_ post: Post) {
        guard let index = indexOfPost(id: post.id) else { return }
        let previous = posts[index]
        if previous.hasSameCardContent(as: post) {
            FeedSignposts.postEquality(changed: false)
            return
        }
        let stamped = post.ensuringVersion(relativeTo: previous)
        posts[index] = stamped
        if let name = stamped.companionGroupName {
            cachedCompanionGroupNames[stamped.id] = name
        }
        FeedSignposts.postEquality(changed: true)
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

    private func indexOfPost(id: UUID) -> Int? {
        if let index = postIndexById[id], posts.indices.contains(index), posts[index].id == id {
            return index
        }
        // Fallback + heal index if drifted.
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return nil }
        postIndexById[id] = index
        return index
    }

    private func assignPosts(_ newPosts: [Post], preserveVersionsFrom _: [Post]?) {
        posts = newPosts
        rebuildPostIndex()
        companionIndexDirty = true
        _ = companionGroupNameIndex()
    }

    private func reapplyFriendDisplayNames() async {
        guard let friendDisplayNameStore, !posts.isEmpty else { return }
        let resolved = await friendDisplayNameStore.resolve(posts)
        let updated = zip(posts, resolved).map { current, resolvedPost in
            current.hasSameCardContent(as: resolvedPost)
                ? current
                : resolvedPost.withVersion(current.version &+ 1)
        }
        guard updated != posts else { return }
        assignPosts(updated, preserveVersionsFrom: nil)
    }

    private func rebuildPostIndex() {
        var index: [UUID: Int] = [:]
        index.reserveCapacity(posts.count)
        for (i, post) in posts.enumerated() {
            index[post.id] = i
        }
        postIndexById = index
    }

    private func prefetchImages(for posts: [Post]) {
        let snapshot = posts
        let mediaDecodeSide = FeedMediaLayout.decodeMaxPixelSide
        let avatarDecodeSide = RemoteImageMetrics.avatarMaxPixelWidth(pointSize: 32)
        Task.detached(priority: .utility) {
            let signpost = FeedSignposts.beginImagePrefetch()
            var mediaURLs: [URL] = []
            var avatarURLs: [URL] = []
            mediaURLs.reserveCapacity(snapshot.count)
            avatarURLs.reserveCapacity(snapshot.count)
            for post in snapshot {
                if let thumb = post.thumbnailURL {
                    mediaURLs.append(thumb)
                } else if let first = post.displayMediaItems.first {
                    mediaURLs.append(first.thumbnailURL ?? first.mediaURL)
                } else {
                    mediaURLs.append(post.imageURL)
                }
                if let avatar = post.author.avatarURL {
                    avatarURLs.append(avatar)
                }
            }
            await MainActor.run {
                ImagePrefetching.prefetch(urls: mediaURLs, thumbnailWidth: mediaDecodeSide)
                ImagePrefetching.prefetch(urls: avatarURLs, thumbnailWidth: avatarDecodeSide)
            }
            FeedSignposts.endImagePrefetch(signpost, count: mediaURLs.count + avatarURLs.count)
        }
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
        if indexOfPost(id: id) != nil {
            return .loaded
        }

        do {
            let post = try await fetchPostUseCase.execute(postId: id)
            posts.insert(post, at: 0)
            rebuildPostIndex()
            if let name = post.companionGroupName {
                cachedCompanionGroupNames[post.id] = name
            }
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

        guard let index = indexOfPost(id: postId) else {
            return result
        }

        let post = posts[index]
        let targets: Set<UUID>
        if let targetUserIds, !targetUserIds.isEmpty {
            targets = Set(targetUserIds)
        } else {
            targets = Set(post.billSplit?.splits.filter { !$0.isPaid }.compactMap(\.user?.id) ?? [])
        }

        let optimistic = post.incrementingBillReminders(for: targets)
        posts[index] = optimistic
        markPostsLoaded()

        await refreshPost(id: postId, allowingConcurrentFeedRefresh: true)

        // Keep optimistic counts if the server payload is still missing reminderCount.
        if let refreshedIndex = indexOfPost(id: postId) {
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
