import XCTest
import SplickDomain
import Common
import Storage
import Localization
@testable import FeatureSocialFeed

@MainActor
final class SocialFeedViewModelsCoverageTests: XCTestCase {

    private final class MockStorage: UserDefaultsServiceProtocol {
        private var storage: [String: Any] = [:]
        func set<T: Codable>(_ value: T, for key: String) { storage[key] = value }
        func get<T: Codable>(for key: String) -> T? { storage[key] as? T }
        func setBool(_ value: Bool, for key: String) { storage[key] = value }
        func getBool(for key: String) -> Bool { (storage[key] as? Bool) ?? false }
        func remove(for key: String) { storage.removeValue(forKey: key) }
    }

    func testStreakViewModel() async {
        let repo = MockFeedRepository()
        let useCase = FetchStreakUseCase(repository: repo)
        let viewModel = StreakViewModel(fetchStreakUseCase: useCase)

        viewModel.applyStartupSummary(currentStreak: 5, hasTodayPhoto: true)
        XCTAssertEqual(viewModel.currentStreak, 5)
        XCTAssertTrue(viewModel.hasTodayPhoto)
        XCTAssertFalse(viewModel.anchorMonthID.isEmpty)

        await viewModel.loadIfNeeded()
        XCTAssertFalse(viewModel.monthSections.isEmpty)

        await viewModel.refresh()

        if let section = viewModel.monthSections.first {
            _ = await viewModel.loadOlderMonthIfNeeded(for: section)
        }

        let day = StreakDay(date: Date(), firstPhotoURL: URL(string: "https://cdn.splick.com/p1.jpg"), firstThumbnailURL: nil, photoCount: 1)
        viewModel.selectDay(day)
        XCTAssertEqual(viewModel.selectedDay?.hasPhoto, true)

        viewModel.dismissDayDetail()
        XCTAssertNil(viewModel.selectedDay)
    }

    func testPhotoAlbumViewModel() async {
        let repo = MockFeedRepository()
        let useCase = FetchPhotoAlbumUseCase(repository: repo)
        let viewModel = PhotoAlbumViewModel(fetchPhotoAlbumUseCase: useCase)

        XCTAssertFalse(viewModel.hasActiveFilters)

        await viewModel.loadInitialIfNeeded()

        let languageService = LanguageService(userDefaults: MockStorage())
        let sections = viewModel.daySections(languageService: languageService)
        XCTAssertTrue(sections.isEmpty)

        await viewModel.refresh()
        await viewModel.loadMore()

        viewModel.setCaptionQuery("coffee")
        var newFilters = PhotoAlbumFilters()
        newFilters.captionQuery = "coffee"
        await viewModel.applyFilters(newFilters)
        XCTAssertTrue(viewModel.hasActiveFilters)

        await viewModel.clearFilters()
        XCTAssertFalse(viewModel.hasActiveFilters)
    }

    func testPostDetailViewModel() async {
        let postId = UUID()
        let commentAuthor = UserSummary(id: UUID(), username: "john", displayName: "John", avatarURL: nil)
        let rootComment = PostComment(id: UUID(), author: commentAuthor, text: "Root comment", mentions: [])
        let replyComment = PostComment(id: UUID(), author: commentAuthor, text: "Reply comment", parentCommentId: rootComment.id, mentions: [])

        let viewModel = PostDetailViewModel(postId: postId) { _, page, limit, filter in
            CommentThreadPage(comments: [rootComment, replyComment], page: page, limit: limit, hasMore: false)
        }

        XCTAssertEqual(viewModel.postId, postId)
        XCTAssertFalse(viewModel.commentsLoaded)

        await viewModel.loadInitial()
        XCTAssertTrue(viewModel.commentsLoaded)
        XCTAssertEqual(viewModel.displayedTopLevel.count, 1)

        await viewModel.setFilter(.evidence)

        let newComment = PostComment(id: UUID(), author: commentAuthor, text: "Optimistic", mentions: [])
        viewModel.upsertOptimistic(newComment)
        XCTAssertEqual(viewModel.allComments.count, 3)

        await viewModel.loadNextPage()
        await viewModel.reload()
    }

    func testFirstPendingEvidenceCommentIdPrefersModeratable() {
        let author = UserSummary(id: UUID(), username: "a", displayName: "A", avatarURL: nil)
        let other = UserSummary(id: UUID(), username: "b", displayName: "B", avatarURL: nil)
        let olderPending = PostComment(
            id: UUID(),
            author: other,
            text: "Paid",
            createdAt: Date(timeIntervalSince1970: 1),
            commentType: .evidence,
            evidenceId: UUID(),
            evidenceStatus: .pending,
            mentions: []
        )
        let newerPending = PostComment(
            id: UUID(),
            author: other,
            text: "Paid again",
            createdAt: Date(timeIntervalSince1970: 2),
            commentType: .evidence,
            evidenceId: UUID(),
            evidenceStatus: .pending,
            mentions: []
        )
        let approved = PostComment(
            id: UUID(),
            author: other,
            text: "Done",
            createdAt: Date(timeIntervalSince1970: 0),
            commentType: .evidence,
            evidenceId: UUID(),
            evidenceStatus: .approved,
            mentions: []
        )
        let standard = PostComment(id: UUID(), author: author, text: "Hi", mentions: [])

        let comments = [standard, approved, newerPending, olderPending]
        XCTAssertEqual(
            PostDetailViewModel.firstPendingEvidenceCommentId(in: comments),
            olderPending.id
        )
        XCTAssertEqual(
            PostDetailViewModel.firstPendingEvidenceCommentId(in: comments) { $0.id == newerPending.id },
            newerPending.id
        )
        XCTAssertNil(
            PostDetailViewModel.firstPendingEvidenceCommentId(in: [standard, approved])
        )
    }

    func testMentionFriendsViewModel() async {
        struct MockFetchFriends: FetchFriendsUseCaseProtocol {
            func execute(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
                [
                    UserSummary(id: UUID(), username: "alice", displayName: "Alice", avatarURL: nil),
                    UserSummary(id: UUID(), username: "bob", displayName: "Bob", avatarURL: nil)
                ]
            }
        }

        let viewModel = MentionFriendsViewModel(useCase: MockFetchFriends(), pageSize: 2)

        viewModel.reset(query: "a")
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(viewModel.friends.isEmpty)

        let lastFriend = viewModel.friends.last
        await viewModel.loadMoreIfNeeded(currentFriend: lastFriend)
    }

    func testFeedViewModel() async {
        let repo = MockFeedRepository()
        let fetchFeedUseCase = FetchFeedUseCase(repository: repo)
        let fetchPostUseCase = FetchPostUseCase(repository: repo)
        let reactToPostUseCase = ReactToPostUseCase(repository: repo)
        let deletePostUseCase = DeletePostUseCase(repository: repo)
        let updatePostUseCase = UpdatePostUseCase(repository: repo)
        let editHistoryUseCase = FetchPostEditHistoryUseCase(repository: repo)
        let addCommentUseCase = AddCommentUseCase(repository: repo)
        let sendReminderUseCase = SendBillReminderUseCase(repository: repo)
        let submitEvidenceUseCase = SubmitPaymentEvidenceUseCase(repository: repo)
        let approveEvidenceUseCase = ApprovePaymentEvidenceUseCase(repository: repo)
        let rejectEvidenceUseCase = RejectPaymentEvidenceUseCase(repository: repo)
        let createPostUseCase = CreatePostUseCase(repository: repo)

        let languageService = LanguageService(userDefaults: MockStorage())

        let viewModel = FeedViewModel(
            fetchFeedUseCase: fetchFeedUseCase,
            fetchPostUseCase: fetchPostUseCase,
            reactToPostUseCase: reactToPostUseCase,
            deletePostUseCase: deletePostUseCase,
            updatePostUseCase: updatePostUseCase,
            fetchPostEditHistoryUseCase: editHistoryUseCase,
            addCommentUseCase: addCommentUseCase,
            sendBillReminderUseCase: sendReminderUseCase,
            submitPaymentEvidenceUseCase: submitEvidenceUseCase,
            approvePaymentEvidenceUseCase: approveEvidenceUseCase,
            rejectPaymentEvidenceUseCase: rejectEvidenceUseCase,
            createPostUseCase: createPostUseCase,
            languageService: languageService,
            feedRepository: repo
        )

        XCTAssertEqual(viewModel.posts.count, 0)

        await viewModel.loadFeedIfNeeded()
        await viewModel.loadFeed(isPullToRefresh: true)
        await viewModel.loadMore()

        let p1 = Post(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "author", displayName: "Author", avatarURL: nil),
            imageURL: URL(string: "https://cdn.splick.com/test.jpg")!,
            caption: "Post 1",
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

        viewModel.prependCreatedPost(p1)
        XCTAssertEqual(viewModel.posts.count, 1)

        await viewModel.react(to: p1.id, emoji: "🔥")
        await viewModel.deletePost(id: p1.id)
        XCTAssertEqual(viewModel.posts.count, 0)
    }
}
