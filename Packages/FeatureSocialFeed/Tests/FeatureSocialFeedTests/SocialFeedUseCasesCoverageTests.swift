import XCTest
import SplickDomain
import FeatureNotification
import FeatureMessaging
@testable import FeatureSocialFeed

final class SocialFeedUseCasesCoverageTests: XCTestCase {

    func testFetchPhotoAlbumUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = FetchPhotoAlbumUseCase(repository: repo)

        let filters = PhotoAlbumFilters()
        let firstPage = try await useCase.fetchFirstPage(filters: filters)
        XCTAssertEqual(firstPage.photos.count, 0)

        let nextPage = try await useCase.fetchNextPage(filters: filters, cursor: "cursor123")
        XCTAssertEqual(nextPage.photos.count, 0)
    }

    func testFetchStreakUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = FetchStreakUseCase(repository: repo)

        let summary = try await useCase.fetchSummary()
        XCTAssertEqual(summary.currentStreak, 5)

        let calendar = try await useCase.fetchCalendar(year: 2026, month: 9)
        XCTAssertTrue(calendar.isEmpty)

        let photos = try await useCase.fetchDayPhotos(date: "2026-09-20")
        XCTAssertTrue(photos.isEmpty)
    }

    func testFetchAppStartupUseCase() async throws {
        struct MockAppStartupRepository: AppStartupRepositoryProtocol {
            func fetchStartupData() async throws -> AppStartupData {
                AppStartupData(
                    badgeCounts: TabBadgeCounts(notifications: 1, friends: 0, expenses: 0, messages: 0, inbox: 0),
                    posts: [],
                    conversations: [],
                    emojis: [],
                    currentStreak: 1,
                    hasTodayPhoto: false
                )
            }
            func loadCached(userId: UUID) async -> AppStartupData? { nil }
            func saveCached(_ data: AppStartupData, userId: UUID) async {}
        }

        let repo = MockAppStartupRepository()
        let useCase = FetchAppStartupUseCase(repository: repo)
        let startup = try await useCase.execute()
        XCTAssertEqual(startup.currentStreak, 1)
    }

    func testFetchUserPostsUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = FetchUserPostsUseCase(repository: repo, pageSize: 10)

        let userId = UUID()
        let posts = try await useCase.execute(authorId: userId, page: 1)
        XCTAssertEqual(repo.lastAuthorId, userId)
        XCTAssertEqual(repo.lastPage, 1)
        XCTAssertEqual(repo.lastLimit, 10)
        XCTAssertTrue(posts.isEmpty)
    }

    func testFetchFriendsUseCase() async throws {
        struct MockFriendsRepository: FriendsRepositoryProtocol {
            func fetchFriends(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
                [UserSummary(id: UUID(), username: "friend1", displayName: "Friend 1", avatarURL: nil)]
            }
        }

        let repo = MockFriendsRepository()
        let useCase = FetchFriendsUseCase(repository: repo)
        let friends = try await useCase.execute(query: "friend", page: 1, limit: 10)
        XCTAssertEqual(friends.count, 1)
        XCTAssertEqual(friends.first?.username, "friend1")
    }

    func testUpdatePostUseCaseAndHistory() async throws {
        let repo = MockFeedRepository()
        let updateUseCase = UpdatePostUseCase(repository: repo)

        let postId = UUID()
        let input = UpdatePostInput(
            postId: postId,
            caption: "Updated caption",
            mediaItems: [],
            audience: .friends,
            companionIds: []
        )
        let post = try await updateUseCase.execute(input)
        XCTAssertEqual(post.id, postId)

        let historyUseCase = FetchPostEditHistoryUseCase(repository: repo)
        let edits = try await historyUseCase.execute(postId: postId)
        XCTAssertTrue(edits.isEmpty)
    }

    func testListPostReactionsUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = ListPostReactionsUseCase(repository: repo)

        let reactions = try await useCase.execute(postId: UUID())
        XCTAssertTrue(reactions.isEmpty)
    }

    func testAddCommentUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = AddCommentUseCase(repository: repo)

        let postId = UUID()
        try await useCase.execute(
            postId: postId,
            body: "Great post!",
            parentCommentId: nil,
            submissionAttachments: []
        )
    }

    func testFetchPostUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = FetchPostUseCase(repository: repo)

        let postId = UUID()
        let post = try await useCase.execute(postId: postId)
        XCTAssertEqual(post.id, postId)
    }

    func testSendBillReminderUseCase() async throws {
        let repo = MockFeedRepository()
        let useCase = SendBillReminderUseCase(repository: repo)

        let res = try await useCase.execute(
            postId: UUID(),
            targetUserIds: nil,
            message: "Reminder to pay",
            submissionAttachments: []
        )
        XCTAssertEqual(res.sentCount, 1)
    }
}
