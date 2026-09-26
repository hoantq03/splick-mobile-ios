import XCTest
import Networking
import SplickDomain
import Storage
import FeatureMedia
import Common
@testable import FeatureSocialFeed

final class FeedRepositoryTests: XCTestCase {

    private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
        var mockResponse: Any?
        var errorToThrow: Error?

        func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
            if let error = errorToThrow {
                throw error
            }
            if let response = mockResponse as? T {
                return response
            }
            throw NetworkError.unknown("Mock missing")
        }

        func request(_ endpoint: APIEndpoint) async throws {
            if let error = errorToThrow {
                throw error
            }
        }

        func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T {
            if let error = errorToThrow {
                throw error
            }
            if let response = mockResponse as? T {
                return response
            }
            throw NetworkError.unknown("Mock missing")
        }
    }

    private final class MockMediaRepository: MediaRepositoryProtocol, @unchecked Sendable {
        var uploadResult: MediaUploadResult?
        var errorToThrow: Error?

        func uploadImage(data: Data, mimeType: String, purpose: MediaUploadPurpose, groupId: UUID?) async throws -> MediaUploadResult {
            if let error = errorToThrow {
                throw error
            }
            return uploadResult ?? MediaUploadResult(
                id: UUID(),
                url: URL(string: "https://cdn.splick.com/test.jpg")!,
                thumbnailURL: URL(string: "https://cdn.splick.com/thumb.jpg")!,
                sizeBytes: data.count
            )
        }

        func deleteMedia(id: UUID) async throws {}
    }

    private func makeAuthorDTO() -> AuthorDTO {
        AuthorDTO(id: UUID(), username: "john", displayName: "John", avatarUrl: nil, viewedAt: nil)
    }

    func testFetchFeedAndAheadCount() async throws {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        let samplePostDTO = PostDTO(
            id: UUID(),
            author: makeAuthorDTO(),
            imageUrl: "https://cdn.splick.com/pic.jpg",
            thumbnailUrl: nil,
            caption: "Hello",
            reactions: [],
            reactionCount: 0,
            reactorCount: 0,
            reactionPreview: [],
            groupId: nil,
            createdAt: Date(),
            mediaType: "IMAGE",
            videoUrl: nil,
            videoDurationSeconds: nil,
            companions: [],
            feedKind: "CHECK_IN",
            checkInPlace: nil,
            location: nil,
            mediaItems: [],
            billSplit: nil,
            comments: [],
            commentCount: 0,
            viewCount: 1,
            viewers: [],
            audience: nil,
            editedAt: nil,
            mentions: []
        )

        apiClient.mockResponse = [samplePostDTO]
        let feed = try await repo.fetchFeed(page: 1, limit: 10, authorId: nil)
        XCTAssertEqual(feed.count, 1)
        XCTAssertEqual(feed.first?.caption, "Hello")

        apiClient.mockResponse = FeedAheadCountDTO(count: 5)
        let aheadCount = try await repo.countFeedPostsAhead(afterCreatedAt: Date(), afterId: UUID())
        XCTAssertEqual(aheadCount, 5)
    }

    func testRecordPostViewsAndCache() async {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        let emptyResult = try? await repo.recordPostViews(postIds: [])
        XCTAssertEqual(emptyResult?.count, 0)

        let userId = UUID()
        let samplePost = Post(
            id: UUID(),
            author: UserSummary(id: userId, username: "john", displayName: "John", avatarURL: nil),
            imageURL: URL(string: "https://cdn.splick.com/pic.jpg")!,
            caption: "Cached",
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

        await repo.saveCachedFeed([samplePost], userId: userId)
        let cachedFeed = await repo.loadCachedFeed(userId: userId)
        XCTAssertNotNil(cachedFeed)
        XCTAssertEqual(cachedFeed?.first?.caption, "Cached")
    }

    func testPhotoAlbumPagination() async throws {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        let photoDTO = AlbumPhotoDTO(
            mediaItemId: UUID(),
            postId: UUID(),
            author: makeAuthorDTO(),
            groupId: nil,
            caption: nil,
            mediaUrl: "https://cdn.splick.com/album.jpg",
            thumbnailUrl: nil,
            mediaType: "IMAGE",
            sortOrder: 0,
            createdAt: Date(),
            checkInPlace: nil,
            location: nil,
            companions: []
        )

        apiClient.mockResponse = [photoDTO]
        let page1 = try await repo.fetchPhotoAlbumFirstPage(limit: 1, filters: PhotoAlbumFilters())
        XCTAssertEqual(page1.photos.count, 1)
        XCTAssertNotNil(page1.nextCursor)

        let pageDTO = AlbumPhotoPageDTO(items: [photoDTO], nextCursor: "next123")
        apiClient.mockResponse = pageDTO
        let page2 = try await repo.fetchPhotoAlbumNextPage(limit: 1, filters: PhotoAlbumFilters(), cursor: page1.nextCursor!)
        XCTAssertEqual(page2.photos.count, 1)
        XCTAssertEqual(page2.nextCursor, "next123")
    }

    func testPostFetchCommentsAndReactions() async throws {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        let postId = UUID()

        let postDTO = PostDTO(
            id: postId,
            author: makeAuthorDTO(),
            imageUrl: "https://cdn.splick.com/pic.jpg",
            thumbnailUrl: nil,
            caption: "Test",
            reactions: [],
            reactionCount: 0,
            reactorCount: 0,
            reactionPreview: [],
            groupId: nil,
            createdAt: Date(),
            mediaType: "IMAGE",
            videoUrl: nil,
            videoDurationSeconds: nil,
            companions: [],
            feedKind: "CHECK_IN",
            checkInPlace: nil,
            location: nil,
            mediaItems: [],
            billSplit: nil,
            comments: [],
            commentCount: 0,
            viewCount: 0,
            viewers: [],
            audience: nil,
            editedAt: nil,
            mentions: []
        )
        apiClient.mockResponse = postDTO
        let post = try await repo.fetchPost(id: postId)
        XCTAssertEqual(post.id, postId)

        let commentThreadDTO = CommentThreadPageDTO(comments: [], page: 1, limit: 10, hasMore: false)
        apiClient.mockResponse = commentThreadDTO
        let commentPage = try await repo.fetchPostComments(postId: postId, page: 1, limit: 10, filter: .all)
        XCTAssertFalse(commentPage.hasMore)

        let reactionsDTO = PostReactionsDTO(reactionCount: 0, reactorCount: 0, items: [])
        apiClient.mockResponse = reactionsDTO
        let reactions = try await repo.fetchPostReactions(postId: postId)
        XCTAssertTrue(reactions.isEmpty)

        let reactionDTO = ReactionDTO(id: UUID(), emoji: "👍", userId: UUID(), createdAt: Date())
        apiClient.mockResponse = reactionDTO
        let addedReaction = try await repo.addReaction(postId: postId, emoji: "👍")
        XCTAssertEqual(addedReaction.emoji, "👍")

        apiClient.mockResponse = nil
        try await repo.removeReaction(postId: postId, reactionId: addedReaction.id)
        try await repo.deletePost(id: postId)
    }

    func testCreatePostWithMediaAndBillSplit() async throws {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        let postId = UUID()
        let postDTO = PostDTO(
            id: postId,
            author: makeAuthorDTO(),
            imageUrl: "https://cdn.splick.com/pic.jpg",
            thumbnailUrl: nil,
            caption: "Dinner",
            reactions: [],
            reactionCount: 0,
            reactorCount: 0,
            reactionPreview: [],
            groupId: nil,
            createdAt: Date(),
            mediaType: "IMAGE",
            videoUrl: nil,
            videoDurationSeconds: nil,
            companions: [],
            feedKind: "SHARE_BILL",
            checkInPlace: nil,
            location: nil,
            mediaItems: [],
            billSplit: nil,
            comments: [],
            commentCount: 0,
            viewCount: 0,
            viewers: [],
            audience: nil,
            editedAt: nil,
            mentions: []
        )
        apiClient.mockResponse = postDTO

        let input = CreatePostInput(
            mediaItems: [
                CreatePostMediaInput(data: Data("img".utf8), mimeType: "image/jpeg", mediaType: .image, videoDurationSeconds: nil)
            ],
            caption: "Dinner",
            companionIds: [],
            companionGroupName: nil,
            checkInPlace: nil,
            location: PostPlace(placeId: "p1", displayName: "Loc", lat: 10.0, lon: 106.0),
            feedKind: .shareBill,
            billSplit: PostBillSplit(
                totalAmount: 100000,
                currency: "VND",
                splits: [
                    PostBillSplitLine(user: UserSummary(id: UUID(), username: "p1", displayName: "P1", avatarURL: nil), amount: 50000),
                    PostBillSplitLine(user: UserSummary(id: UUID(), username: "p2", displayName: "P2", avatarURL: nil), amount: 50000)
                ]
            ),
            billSplitType: "EXACT",
            autoReminderEnabled: true,
            pendingCompanions: [PendingCompanionInput(displayName: "Guest", email: "guest@example.com", amount: 10000)],
            audience: PostAudience(mode: .specificUsers, allowedUserIds: [UUID()]),
            groupId: UUID(),
            groupIds: [UUID()]
        )

        let createdPost = try await repo.createPost(input)
        XCTAssertEqual(createdPost.id, postId)

        let emptyMediaInput = CreatePostInput(mediaItems: [], caption: "Fail", feedKind: .checkIn)
        do {
            _ = try await repo.createPost(emptyMediaInput)
            XCTFail("Should fail with missing media items")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    func testAddCommentWithAttachments() async throws {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        apiClient.mockResponse = nil

        let preUploadedAttachment = CommentSubmissionAttachment(
            kind: .image,
            uploadedMediaId: UUID(),
            url: URL(string: "https://cdn.splick.com/pre.jpg")!,
            thumbnailURL: URL(string: "https://cdn.splick.com/pre_thumb.jpg"),
            sizeBytes: 100,
            fileName: "img.jpg"
        )

        let remoteOnlyAttachment = CommentSubmissionAttachment(
            kind: .image,
            remoteURL: URL(string: "https://example.com/pic.png")!,
            fileName: "link"
        )

        let uploadableAttachment = CommentSubmissionAttachment(
            kind: .image,
            data: Data("test".utf8),
            mimeType: "image/png",
            fileName: "local.png"
        )

        try await repo.addComment(
            postId: UUID(),
            body: "Great dish!",
            parentCommentId: nil,
            submissionAttachments: [preUploadedAttachment, remoteOnlyAttachment, uploadableAttachment]
        )
    }

    func testUpdatePostAndEdits() async throws {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        let postId = UUID()
        let postDTO = PostDTO(
            id: postId,
            author: makeAuthorDTO(),
            imageUrl: "https://cdn.splick.com/pic.jpg",
            thumbnailUrl: nil,
            caption: "Updated caption",
            reactions: [],
            reactionCount: 0,
            reactorCount: 0,
            reactionPreview: [],
            groupId: nil,
            createdAt: Date(),
            mediaType: "IMAGE",
            videoUrl: nil,
            videoDurationSeconds: nil,
            companions: [],
            feedKind: "CHECK_IN",
            checkInPlace: nil,
            location: nil,
            mediaItems: [],
            billSplit: nil,
            comments: [],
            commentCount: 0,
            viewCount: 0,
            viewers: [],
            audience: nil,
            editedAt: nil,
            mentions: []
        )
        apiClient.mockResponse = postDTO

        let existingMedia = PostMediaItem(
            id: UUID(),
            mediaURL: URL(string: "https://cdn.splick.com/ex.jpg")!,
            thumbnailURL: nil,
            mediaType: .image,
            durationSeconds: nil,
            widthPx: 100,
            heightPx: 100,
            sortOrder: 0
        )

        let updateInput = UpdatePostInput(
            postId: postId,
            caption: "Updated caption",
            mediaItems: [
                .existing(existingMedia),
                .uploaded(data: Data("new".utf8), mimeType: "image/jpeg", mediaType: .image, videoDurationSeconds: nil)
            ],
            audience: .friends,
            companionIds: []
        )

        let updatedPost = try await repo.updatePost(updateInput)
        XCTAssertEqual(updatedPost.caption, "Updated caption")

        let editsResponse = PostEditsResponseDTO(items: [])
        apiClient.mockResponse = editsResponse
        let edits = try await repo.fetchPostEdits(postId: postId)
        XCTAssertTrue(edits.isEmpty)
    }

    func testBillRemindersAndEvidence() async throws {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        let postId = UUID()

        apiClient.mockResponse = SendPostBillReminderResponseDTO(sentCount: 2, skippedCount: 0)
        let reminderRes = try await repo.sendBillReminder(postId: postId, targetUserIds: nil, message: "Pay please", submissionAttachments: [])
        XCTAssertEqual(reminderRes.sentCount, 2)

        let evId = UUID()
        let commId = UUID()
        apiClient.mockResponse = SubmitPaymentEvidenceResponseDTO(evidenceId: evId, commentId: commId)
        let evRes = try await repo.submitPaymentEvidence(postId: postId, splitId: UUID(), message: "Paid", submissionAttachments: [])
        XCTAssertEqual(evRes.evidenceId, evId)

        apiClient.mockResponse = nil
        try await repo.approvePaymentEvidence(postId: postId, evidenceId: evId)
        try await repo.rejectPaymentEvidence(postId: postId, evidenceId: evId, reason: "Invalid screenshot")
    }

    func testStreakAndLocations() async throws {
        let apiClient = MockAPIClient()
        let mediaRepo = MockMediaRepository()
        let repo = FeedRepository(apiClient: apiClient, mediaRepository: mediaRepo)

        apiClient.mockResponse = StreakSummaryDTO(currentStreak: 10, hasTodayPhoto: true)
        let streak = try await repo.fetchStreakSummary()
        XCTAssertEqual(streak.currentStreak, 10)

        apiClient.mockResponse = [StreakDayDTO(date: "2026-09-20", firstPhotoUrl: "https://cdn.splick.com/p1.jpg", firstThumbnailUrl: nil, photoCount: 1)]
        let calendar = try await repo.fetchStreakCalendar(year: 2026, month: 9)
        XCTAssertEqual(calendar.count, 1)

        apiClient.mockResponse = [
            AlbumPhotoDTO(
                mediaItemId: UUID(),
                postId: UUID(),
                author: makeAuthorDTO(),
                groupId: nil,
                caption: nil,
                mediaUrl: "https://cdn.splick.com/p.jpg",
                thumbnailUrl: nil,
                mediaType: "IMAGE",
                sortOrder: 0,
                createdAt: Date(),
                checkInPlace: nil,
                location: nil,
                companions: []
            )
        ]
        let dayPhotos = try await repo.fetchStreakDayPhotos(date: "2026-09-20")
        XCTAssertEqual(dayPhotos.count, 1)

        let locSearchResponse = LocationSearchResponseDTO(locations: [PostLocationDTO(placeId: "p1", displayName: "Cafe", lat: 21.0, lon: 105.8)])
        apiClient.mockResponse = locSearchResponse

        let searchRes = try await repo.searchLocations(query: "Cafe", lat: 21.0, lon: 105.8)
        XCTAssertEqual(searchRes.count, 1)

        let nearbyRes = try await repo.nearbyLocations(lat: 21.0, lon: 105.8, radiusMeters: 500)
        XCTAssertEqual(nearbyRes.count, 1)
    }
}
