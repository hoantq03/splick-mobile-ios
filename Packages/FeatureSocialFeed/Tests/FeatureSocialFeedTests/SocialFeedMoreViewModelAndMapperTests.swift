import XCTest
import SwiftUI
import SplickDomain
import Common
import Storage
import Localization
@testable import FeatureSocialFeed

@MainActor
final class SocialFeedMoreViewModelAndMapperTests: XCTestCase {

    private final class MockStorage: UserDefaultsServiceProtocol {
        private var storage: [String: Any] = [:]
        func set<T: Codable>(_ value: T, for key: String) { storage[key] = value }
        func get<T: Codable>(for key: String) -> T? { storage[key] as? T }
        func setBool(_ value: Bool, for key: String) { storage[key] = value }
        func getBool(for key: String) -> Bool { (storage[key] as? Bool) ?? false }
        func remove(for key: String) { storage.removeValue(forKey: key) }
    }

    func testVNDMoneyFormat() {
        let formatted = VNDMoneyFormat.format(100000)
        XCTAssertFalse(formatted.isEmpty)
        let display = VNDMoneyFormat.formatDisplay(100000)
        XCTAssertTrue(display.contains(formatted))
        let parsed = VNDMoneyFormat.parse("150.000 đ")
        XCTAssertEqual(parsed, 150000)
        XCTAssertNil(VNDMoneyFormat.parse(""))
        XCTAssertEqual(VNDMoneyFormat.sanitizedInput(from: "abc100000xyz"), VNDMoneyFormat.format(100000))
        XCTAssertEqual(VNDMoneyFormat.parsePercent("50,5"), 50.5)

        var storageString = ""
        let binding = VNDMoneyFormat.moneyBinding(Binding(get: { storageString }, set: { storageString = $0 }))
        binding.wrappedValue = "100000"
        XCTAssertEqual(storageString, VNDMoneyFormat.format(100000))

        var percentString = ""
        let percentBinding = VNDMoneyFormat.percentBinding(Binding(get: { percentString }, set: { percentString = $0 }))
        percentBinding.wrappedValue = "50,5%"
        XCTAssertEqual(percentString, "50,5")
        percentBinding.wrappedValue = "150"
        XCTAssertEqual(percentString, "100")
    }

    func testPhotoAlbumFilters() {
        var filters = PhotoAlbumFilters()
        XCTAssertFalse(filters.hasAnyFilter)
        XCTAssertNil(filters.apiCaptionQuery)

        filters.captionQuery = "a"
        XCTAssertEqual(filters.apiCaptionQuery, "a")
        XCTAssertTrue(filters.hasAnyFilter)

        filters.captionQuery = "query"
        XCTAssertTrue(filters.hasAnyFilter)

        filters.clearAll()
        XCTAssertFalse(filters.hasAnyFilter)

        let user = UserSummary(id: UUID(), username: "u", displayName: "U", avatarURL: nil)
        filters.authors = [user]
        XCTAssertTrue(filters.hasAdvancedFilters)
    }

    func testUpdatePostInputAndItem() {
        let existingMedia = PostMediaItem(
            id: UUID(),
            mediaURL: URL(string: "https://cdn.splick.com/m.jpg")!,
            thumbnailURL: nil,
            mediaType: .image,
            durationSeconds: nil,
            widthPx: 100,
            heightPx: 100,
            sortOrder: 0
        )
        let item1 = UpdatePostMediaItem.existing(existingMedia)
        let item2 = UpdatePostMediaItem.uploaded(data: Data(), mimeType: "image/jpeg", mediaType: .image, videoDurationSeconds: nil)

        let input = UpdatePostInput(
            postId: UUID(),
            caption: "Cap",
            mediaItems: [item1, item2],
            audience: .friends,
            companionIds: []
        )
        XCTAssertEqual(input.caption, "Cap")
        XCTAssertEqual(input.mediaItems.count, 2)
    }

    func testDeleteStreakRisk() async {
        let post = Post(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "u", displayName: "U", avatarURL: nil),
            imageURL: URL(string: "https://cdn.splick.com/img.jpg")!,
            caption: "Image post",
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

        XCTAssertTrue(DeleteStreakRisk.hasImage(post))
        let dayStr = DeleteStreakRisk.utcDateString(post.createdAt)
        XCTAssertFalse(dayStr.isEmpty)

        let inWindow = DeleteStreakRisk.isInLiveStreakWindow(
            day: dayStr,
            today: dayStr,
            currentStreak: 5,
            hasTodayPhoto: true
        )
        XCTAssertTrue(inWindow)

        let warning = await DeleteStreakRisk.streakDaysIfDeleteBreaks(
            post: post,
            knownPosts: [],
            fetchSummary: { StreakSummary(currentStreak: 5, hasTodayPhoto: true) },
            fetchDayPhotos: { _ in [AlbumPhoto(id: UUID(), postId: post.id, author: post.author, mediaURL: post.imageURL, thumbnailURL: nil, mediaType: .image, sortOrder: 0, createdAt: Date())] }
        )
        XCTAssertEqual(warning?.streakDays, 5)

        if let warning {
            let pending = PendingStreakDelete(postId: post.id, warning: warning)
            XCTAssertEqual(pending.id, post.id)
        }
    }

    func testAlbumPhotoDaySection() {
        let photo = AlbumPhoto(
            id: UUID(),
            postId: UUID(),
            author: UserSummary(id: UUID(), username: "u", displayName: "U", avatarURL: nil),
            mediaURL: URL(string: "https://cdn.splick.com/a.jpg")!,
            thumbnailURL: nil,
            mediaType: .image,
            sortOrder: 0,
            createdAt: Date()
        )

        let sections = AlbumPhotoSectionBuilder.daySections(from: [photo], todayTitle: "Today", yesterdayTitle: "Yesterday")
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.photos.count, 1)
    }

    func testFeedEndpointCoverage() {
        let postId = UUID()
        let evidenceId = UUID()
        let requestDTO = RejectPaymentEvidenceRequestDTO(reason: "Invalid")

        let rejectEp = FeedEndpoint.rejectPaymentEvidence(postId: postId, evidenceId: evidenceId, requestDTO)
        XCTAssertEqual(rejectEp.path, "/v1/feed/posts/\(postId)/payments/evidence/\(evidenceId)/reject")
        XCTAssertEqual(rejectEp.method, .post)
        XCTAssertNotNil(rejectEp.body)

        let reminderRequest = SendPostBillReminderRequestDTO(targetUserIds: nil, message: "Pay", attachments: [])
        let reminderEp = FeedEndpoint.sendBillReminder(postId: postId, reminderRequest)
        XCTAssertEqual(reminderEp.path, "/v1/feed/posts/\(postId)/reminders")
        XCTAssertEqual(reminderEp.method, .post)

        let evidenceRequest = SubmitPaymentEvidenceRequestDTO(splitId: UUID(), message: "Paid", attachments: [])
        let submitEvidenceEp = FeedEndpoint.submitPaymentEvidence(postId: postId, evidenceRequest)
        XCTAssertEqual(submitEvidenceEp.path, "/v1/feed/posts/\(postId)/payments/evidence")
        XCTAssertEqual(submitEvidenceEp.method, .post)
    }

    func testFeedViewModelExtraActions() async {
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

        await viewModel.syncFeedAfterCreatingPost(p1)
        viewModel.revealNewPosts()
        viewModel.beginPullToRefreshIfNeeded()
        viewModel.endRefreshingIfNeeded()
        XCTAssertFalse(viewModel.hasPendingPostUploads)
    }
}
