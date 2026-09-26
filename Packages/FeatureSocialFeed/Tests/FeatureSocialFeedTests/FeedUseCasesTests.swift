import XCTest
import SplickDomain
@testable import FeatureSocialFeed

final class MockFeedRepository: FeedRepositoryProtocol, @unchecked Sendable {
    var posts: [Post] = []
    var lastPage: Int?
    var lastLimit: Int?
    var lastAuthorId: UUID?
    var createdInput: CreatePostInput?
    var deletedPostId: UUID?
    var lastReactionPostId: UUID?
    var lastReactionEmoji: String?
    var lastRecordedPostIds: [UUID]?
    var lastApprovedEvidencePostId: UUID?
    var lastApprovedEvidenceId: UUID?
    var lastRejectedEvidenceReason: String?

    func fetchFeed(page: Int, limit: Int, authorId: UUID?) async throws -> [Post] {
        lastPage = page
        lastLimit = limit
        lastAuthorId = authorId
        return posts
    }

    func countFeedPostsAhead(afterCreatedAt: Date, afterId: UUID) async throws -> Int {
        3
    }

    func fetchPhotoAlbumFirstPage(limit: Int, filters: PhotoAlbumFilters) async throws -> AlbumPhotoPage {
        AlbumPhotoPage(photos: [], nextCursor: nil)
    }

    func fetchPhotoAlbumNextPage(limit: Int, filters: PhotoAlbumFilters, cursor: String) async throws -> AlbumPhotoPage {
        AlbumPhotoPage(photos: [], nextCursor: nil)
    }

    func fetchPost(id: UUID) async throws -> Post {
        posts.first { $0.id == id } ?? Post(
            id: id,
            author: UserSummary(id: UUID(), username: "mock", displayName: "Mock User", avatarURL: nil),
            imageURL: URL(string: "https://cdn.splick.com/test.jpg")!,
            reactions: [],
            reactionCount: 0,
            reactorCount: 0,
            comments: [],
            commentCount: 0,
            createdAt: Date(),
            mediaType: .image,
            feedKind: .checkIn,
            viewCount: 0,
            audience: .friends
        )
    }

    func fetchPostComments(postId: UUID, page: Int, limit: Int, filter: CommentThreadFilter) async throws -> CommentThreadPage {
        CommentThreadPage(comments: [], page: page, limit: limit, hasMore: false)
    }

    func fetchPostReactions(postId: UUID) async throws -> [UserReactionSummary] {
        []
    }

    func recordPostViews(postIds: [UUID]) async throws -> [Post] {
        lastRecordedPostIds = postIds
        return posts
    }

    func addReaction(postId: UUID, emoji: String) async throws -> Reaction {
        lastReactionPostId = postId
        lastReactionEmoji = emoji
        return Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: Date())
    }

    func removeReaction(postId: UUID, reactionId: UUID) async throws {}

    func createPost(_ input: CreatePostInput) async throws -> Post {
        createdInput = input
        let newPost = Post(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "creator", displayName: "Creator", avatarURL: nil),
            imageURL: URL(string: "https://cdn.splick.com/created.jpg")!,
            caption: input.caption,
            reactions: [],
            reactionCount: 0,
            reactorCount: 0,
            comments: [],
            commentCount: 0,
            createdAt: Date(),
            mediaType: .image,
            feedKind: input.feedKind,
            viewCount: 0,
            audience: input.audience
        )
        posts.append(newPost)
        return newPost
    }

    func addComment(
        postId: UUID,
        body: String?,
        parentCommentId: UUID?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws {}

    func deletePost(id: UUID) async throws {
        deletedPostId = id
        posts.removeAll { $0.id == id }
    }

    func updatePost(_ input: UpdatePostInput) async throws -> Post {
        try await fetchPost(id: input.postId)
    }

    func fetchPostEdits(postId: UUID) async throws -> [PostEditRevision] {
        []
    }

    func sendBillReminder(
        postId: UUID,
        targetUserIds: [UUID]?,
        message: String,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SendBillReminderResult {
        SendBillReminderResult(sentCount: 1, skippedCount: 0)
    }

    func submitPaymentEvidence(
        postId: UUID,
        splitId: UUID,
        message: String?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SubmitPaymentEvidenceResult {
        SubmitPaymentEvidenceResult(evidenceId: UUID(), commentId: UUID())
    }

    func approvePaymentEvidence(postId: UUID, evidenceId: UUID) async throws {
        lastApprovedEvidencePostId = postId
        lastApprovedEvidenceId = evidenceId
    }

    func rejectPaymentEvidence(postId: UUID, evidenceId: UUID, reason: String) async throws {
        lastRejectedEvidenceReason = reason
    }

    func fetchStreakSummary() async throws -> StreakSummary {
        StreakSummary(currentStreak: 5, hasTodayPhoto: true)
    }

    func fetchStreakCalendar(year: Int, month: Int) async throws -> [StreakDay] {
        []
    }

    func fetchStreakDayPhotos(date: String) async throws -> [AlbumPhoto] {
        []
    }

    func searchLocations(query: String, lat: Double?, lon: Double?) async throws -> [PostPlace] {
        []
    }

    func nearbyLocations(lat: Double, lon: Double, radiusMeters: Int) async throws -> [PostPlace] {
        []
    }

    func loadCachedFeed(userId: UUID) async -> [Post]? {
        posts
    }

    func saveCachedFeed(_ posts: [Post], userId: UUID) async {
        self.posts = posts
    }
}

final class FeedUseCasesTests: XCTestCase {
    func testFetchFeedUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = FetchFeedUseCase(repository: repo, pageSize: 15)

        let feed = try await useCase.execute(page: 2)
        XCTAssertEqual(repo.lastPage, 2)
        XCTAssertEqual(repo.lastLimit, 15)
        XCTAssertEqual(feed.count, 0)
    }

    func testCreatePostUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = CreatePostUseCase(repository: repo)

        let input = CreatePostInput(
            mediaItems: [],
            caption: "Hello World!",
            feedKind: .checkIn
        )
        let post = try await useCase.execute(input)
        XCTAssertEqual(post.caption, "Hello World!")
        XCTAssertEqual(repo.createdInput?.caption, "Hello World!")
    }

    func testDeletePostUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = DeletePostUseCase(repository: repo)

        let postId = UUID()
        try await useCase.execute(postId: postId)
        XCTAssertEqual(repo.deletedPostId, postId)
    }

    func testReactToPostUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = ReactToPostUseCase(repository: repo)

        let postId = UUID()
        let reaction = try await useCase.execute(postId: postId, emoji: "🚀")
        XCTAssertEqual(reaction.emoji, "🚀")
        XCTAssertEqual(repo.lastReactionPostId, postId)
        XCTAssertEqual(repo.lastReactionEmoji, "🚀")
    }

    func testRecordPostViewsUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = RecordPostViewsUseCase(repository: repo)

        let postIds = [UUID(), UUID()]
        _ = try await useCase.execute(postIds: postIds)
        XCTAssertEqual(repo.lastRecordedPostIds, postIds)
    }

    func testPaymentEvidenceUseCases() async throws {
        let repo = MockFeedRepository()
        let submitUseCase = SubmitPaymentEvidenceUseCase(repository: repo)
        let approveUseCase = ApprovePaymentEvidenceUseCase(repository: repo)
        let rejectUseCase = RejectPaymentEvidenceUseCase(repository: repo)

        let postId = UUID()
        let splitId = UUID()
        let evidenceResult = try await submitUseCase.execute(
            postId: postId,
            splitId: splitId,
            message: "Paid via VietQR",
            submissionAttachments: []
        )
        XCTAssertNotNil(evidenceResult.evidenceId)

        let evidenceId = evidenceResult.evidenceId
        try await approveUseCase.execute(postId: postId, evidenceId: evidenceId)
        XCTAssertEqual(repo.lastApprovedEvidencePostId, postId)
        XCTAssertEqual(repo.lastApprovedEvidenceId, evidenceId)

        try await rejectUseCase.execute(postId: postId, evidenceId: evidenceId, reason: "Wrong transaction ID")
        XCTAssertEqual(repo.lastRejectedEvidenceReason, "Wrong transaction ID")
    }
}
