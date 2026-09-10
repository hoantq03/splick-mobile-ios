import Foundation
import SplickDomain

public protocol FeedRepositoryProtocol: Sendable {
    func fetchFeed(page: Int, limit: Int, authorId: UUID?) async throws -> [Post]
    func countFeedPostsAhead(afterCreatedAt: Date, afterId: UUID) async throws -> Int
    func fetchPhotoAlbumFirstPage(limit: Int, filters: PhotoAlbumFilters) async throws -> AlbumPhotoPage
    func fetchPhotoAlbumNextPage(
        limit: Int,
        filters: PhotoAlbumFilters,
        cursor: String
    ) async throws -> AlbumPhotoPage
    func fetchPost(id: UUID) async throws -> Post
    func fetchPostComments(
        postId: UUID,
        page: Int,
        limit: Int,
        filter: CommentThreadFilter
    ) async throws -> CommentThreadPage
    /// Grouped reactors with per-emoji counts for the reaction detail sheet.
    func fetchPostReactions(postId: UUID) async throws -> [UserReactionSummary]
    /// Records views for many posts in one call; returns refreshed posts for those recorded.
    func recordPostViews(postIds: [UUID]) async throws -> [Post]
    func addReaction(postId: UUID, emoji: String) async throws -> Reaction
    func removeReaction(postId: UUID, reactionId: UUID) async throws
    func createPost(_ input: CreatePostInput) async throws -> Post
    func addComment(
        postId: UUID,
        body: String?,
        parentCommentId: UUID?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws
    func deletePost(id: UUID) async throws
    func updatePost(_ input: UpdatePostInput) async throws -> Post
    func fetchPostEdits(postId: UUID) async throws -> [PostEditRevision]
    func sendBillReminder(
        postId: UUID,
        targetUserIds: [UUID]?,
        message: String,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SendBillReminderResult

    func submitPaymentEvidence(
        postId: UUID,
        splitId: UUID,
        message: String?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SubmitPaymentEvidenceResult

    func approvePaymentEvidence(postId: UUID, evidenceId: UUID) async throws

    func rejectPaymentEvidence(postId: UUID, evidenceId: UUID, reason: String) async throws

    // MARK: - Streak
    func fetchStreakSummary() async throws -> StreakSummary
    func fetchStreakCalendar(year: Int, month: Int) async throws -> [StreakDay]
    func fetchStreakDayPhotos(date: String) async throws -> [AlbumPhoto]
    func searchLocations(query: String, lat: Double?, lon: Double?) async throws -> [PostPlace]
    func nearbyLocations(lat: Double, lon: Double, radiusMeters: Int) async throws -> [PostPlace]

    // MARK: - Disk cache
    func loadCachedFeed(userId: UUID) async -> [Post]?
    func saveCachedFeed(_ posts: [Post], userId: UUID) async
}

public extension FeedRepositoryProtocol {
    func fetchFeed(page: Int, limit: Int) async throws -> [Post] {
        try await fetchFeed(page: page, limit: limit, authorId: nil)
    }
}
