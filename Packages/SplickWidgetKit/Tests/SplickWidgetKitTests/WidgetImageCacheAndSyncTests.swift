import XCTest
import SplickDomain
@testable import SplickWidgetKit

final class WidgetMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class WidgetImageCacheAndSyncTests: XCTestCase {
    private var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WidgetMockURLProtocol.self]
        mockSession = URLSession(configuration: config)
    }

    override func tearDown() {
        WidgetMockURLProtocol.requestHandler = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - WidgetTimelineReloader

    func testWidgetTimelineReloader() {
        WidgetTimelineReloader.reloadAll()
        WidgetTimelineReloader.reload("ExpenseSummaryWidget", "FriendStreakWidget")
    }

    // MARK: - WidgetImageCache

    func testWidgetImageCacheSuccess() async throws {
        let imageCache = WidgetImageCache(session: mockSession)
        let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // fake JPEG header
        let url = URL(string: "https://example.com/avatar.jpg")!

        WidgetMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, testData)
        }

        let filename = "test_avatar_\(UUID().uuidString).jpg"
        let result = await imageCache.cacheImage(from: url, filename: filename)
        XCTAssertEqual(result, filename)

        let cachedURL = imageCache.imageURL(for: filename)
        XCTAssertNotNil(cachedURL)
        if let cachedURL {
            try? FileManager.default.removeItem(at: cachedURL)
        }
    }

    func testWidgetImageCacheHTTPFailure() async {
        let imageCache = WidgetImageCache(session: mockSession)
        let url = URL(string: "https://example.com/notfound.jpg")!

        WidgetMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let filename = "test_404_\(UUID().uuidString).jpg"
        let result = await imageCache.cacheImage(from: url, filename: filename)
        XCTAssertNil(result)
    }

    func testWidgetImageCacheNetworkError() async {
        let imageCache = WidgetImageCache(session: mockSession)
        let url = URL(string: "https://example.com/error.jpg")!

        WidgetMockURLProtocol.requestHandler = { _ in
            throw URLError(.cannotConnectToHost)
        }

        let filename = "test_err_\(UUID().uuidString).jpg"
        let result = await imageCache.cacheImage(from: url, filename: filename)
        XCTAssertNil(result)
    }

    func testWidgetImageCacheMissingAndNilURL() {
        let imageCache = WidgetImageCache(session: mockSession)
        XCTAssertNil(imageCache.imageURL(for: nil))
        XCTAssertNil(imageCache.imageURL(for: "missing_file_\(UUID().uuidString).jpg"))
        XCTAssertNotNil(WidgetImageCache.shared)
    }

    // MARK: - WidgetDataSyncService & WidgetCacheService

    func testSyncExpenseSummary() {
        let syncService = WidgetDataSyncService()
        let cacheService = WidgetCacheService()

        let u1 = UserSummary(id: UUID(), username: "u1", displayName: "User One")
        let u2 = UserSummary(id: UUID(), username: "u2", displayName: "User Two")
        let u3 = UserSummary(id: UUID(), username: "u3", displayName: "User Three")

        let debts = [
            DebtSummary(user: u1, amount: Decimal(150000), currency: "VND"), // owed to me (+150k)
            DebtSummary(user: u2, amount: Decimal(-50000), currency: "VND"), // I owe (-50k)
            DebtSummary(user: u3, amount: Decimal(20000), currency: "VND")   // owed to me (+20k)
        ]

        syncService.syncExpenseSummary(debts: debts)

        let loaded = cacheService.loadExpenseSummary()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.currency, "VND")
        XCTAssertEqual(loaded?.netAmount, "+120,000₫")
        XCTAssertEqual(loaded?.totalOwed, "170,000₫")
        XCTAssertEqual(loaded?.totalOwing, "50,000₫")
        XCTAssertEqual(loaded?.owedPeopleCount, 2)
        XCTAssertEqual(loaded?.owingPeopleCount, 1)
        XCTAssertEqual(loaded?.topDebts.count, 3)
    }

    func testSyncExpenseSummaryEmptyDebts() {
        let syncService = WidgetDataSyncService()
        let cacheService = WidgetCacheService()

        syncService.syncExpenseSummary(debts: [])

        let loaded = cacheService.loadExpenseSummary()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.currency, "VND")
        XCTAssertEqual(loaded?.netAmount, "0₫")
        XCTAssertEqual(loaded?.owedPeopleCount, 0)
        XCTAssertEqual(loaded?.owingPeopleCount, 0)
        XCTAssertEqual(loaded?.topDebts.isEmpty, true)
    }

    func testSyncGroupExpense() {
        let syncService = WidgetDataSyncService()
        let cacheService = WidgetCacheService()

        let groupId = UUID()
        let owner = UserSummary(id: UUID(), username: "owner", displayName: "Owner")
        let member = UserSummary(id: UUID(), username: "member", displayName: "Member")
        let group = Group(id: groupId, name: "Camping Trip", inviteCode: "CAMP123", createdBy: owner.id)

        let expense1 = Expense(
            id: UUID(),
            description: "Tents",
            totalAmount: Decimal(100000),
            currency: "VND",
            paidBy: owner,
            status: .settled
        )
        let expense2 = Expense(
            id: UUID(),
            description: "Food",
            totalAmount: Decimal(50000),
            currency: "VND",
            paidBy: member,
            status: .pending
        )

        let debts = [
            DebtSummary(user: member, amount: Decimal(50000), currency: "VND")
        ]

        syncService.syncGroupExpense(
            group: group,
            expenses: [expense1, expense2],
            debts: debts,
            currentUserId: owner.id
        )

        let loaded = cacheService.loadGroupExpense(groupId: groupId)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.groupId, groupId)
        XCTAssertEqual(loaded?.groupName, "Camping Trip")
        XCTAssertEqual(loaded?.totalAmount, "150,000₫")
        XCTAssertEqual(loaded?.settledPercentage, 50)
        XCTAssertEqual(loaded?.memberBalances.count, 1)
        XCTAssertEqual(loaded?.memberBalances.first?.displayName, "Member")
        XCTAssertEqual(loaded?.memberBalances.first?.isOwed, true)
    }

    func testSyncGroupExpenseEmptyExpenses() {
        let syncService = WidgetDataSyncService()
        let cacheService = WidgetCacheService()

        let groupId = UUID()
        let owner = UserSummary(id: UUID(), username: "owner", displayName: "Owner")
        let group = Group(id: groupId, name: "Empty Group", inviteCode: "EMPTY1", createdBy: owner.id)

        syncService.syncGroupExpense(group: group, expenses: [], debts: [], currentUserId: nil)

        let loaded = cacheService.loadGroupExpense(groupId: groupId)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.settledPercentage, 0)
        XCTAssertEqual(loaded?.totalAmount, "0₫")
    }

    func testSyncGroups() {
        let syncService = WidgetDataSyncService()
        let cacheService = WidgetCacheService()

        let g1 = Group(id: UUID(), name: "House", inviteCode: "H1", memberCount: 3, createdBy: UUID())
        let g2 = Group(id: UUID(), name: "Travel", inviteCode: "T1", memberCount: 5, createdBy: UUID())

        syncService.syncGroups([g1, g2])

        let loaded = cacheService.loadGroups()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.groups.count, 2)
        XCTAssertEqual(loaded?.groups.first?.name, "House")
        XCTAssertEqual(loaded?.groups.last?.name, "Travel")
    }

    func testSyncMessagingInbox() {
        let syncService = WidgetDataSyncService()
        let cacheService = WidgetCacheService()

        let previewInput = WidgetConversationPreviewInput(
            id: UUID(),
            displayTitle: "Support Chat",
            previewText: "How can I help you?",
            unreadCount: 2,
            avatarURL: "https://example.com/avatar.png",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        syncService.syncMessagingInbox(conversations: [previewInput], totalUnreadCount: 2)

        let loaded = cacheService.loadMessagingInbox()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.totalUnreadCount, 2)
        XCTAssertEqual(loaded?.conversations.count, 1)
        XCTAssertEqual(loaded?.conversations.first?.displayTitle, "Support Chat")
        XCTAssertEqual(loaded?.conversations.first?.unreadCount, 2)
    }

    func testSyncLatestFriendPhoto() async {
        let imageCache = WidgetImageCache(session: mockSession)
        let syncService = WidgetDataSyncService(imageCache: imageCache)
        let cacheService = WidgetCacheService(imageCache: imageCache)

        let currentUserId = UUID()
        let friendId = UUID()
        let friend = UserSummary(id: friendId, username: "friend", displayName: "Best Friend")

        // 1. Nil post resets to blank placeholder
        await syncService.syncLatestFriendPhoto(post: nil, currentUserId: currentUserId)
        var loaded = cacheService.loadLatestFriendPhoto()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.authorName, "")
        XCTAssertNil(loaded?.cachedImageFilename)
        if let loaded {
            XCTAssertNil(cacheService.cachedImageURL(for: loaded))
        }

        // 2. Post by current user is ignored
        let ownPost = Post(
            id: UUID(),
            author: UserSummary(id: currentUserId, username: "me", displayName: "Me"),
            imageURL: URL(string: "https://example.com/img.jpg")!,
            mentions: []
        )
        await syncService.syncLatestFriendPhoto(post: ownPost, currentUserId: currentUserId)
        loaded = cacheService.loadLatestFriendPhoto()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.authorName, "")

        // 3. Post not image is ignored
        let videoPost = Post(
            id: UUID(),
            author: friend,
            imageURL: URL(string: "https://example.com/vid_thumb.jpg")!,
            mediaType: .video,
            mentions: []
        )
        await syncService.syncLatestFriendPhoto(post: videoPost, currentUserId: currentUserId)
        loaded = cacheService.loadLatestFriendPhoto()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.authorName, "")

        // 4. Valid friend image post
        WidgetMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data([0x01, 0x02, 0x03]))
        }

        let validPost = Post(
            id: UUID(),
            author: friend,
            imageURL: URL(string: "https://example.com/friend.jpg")!,
            thumbnailURL: URL(string: "https://example.com/thumb.jpg")!,
            mediaType: .image,
            mentions: []
        )
        await syncService.syncLatestFriendPhoto(post: validPost, currentUserId: currentUserId)

        loaded = cacheService.loadLatestFriendPhoto()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.authorName, "Best Friend")
        XCTAssertEqual(loaded?.authorUsername, "friend")
        XCTAssertEqual(loaded?.postId, validPost.id)
        XCTAssertNotNil(loaded?.cachedImageFilename)
        if let loaded {
            let cachedURL = cacheService.cachedImageURL(for: loaded)
            XCTAssertNotNil(cachedURL)
            if let cachedURL {
                try? FileManager.default.removeItem(at: cachedURL)
            }
        }

        // 5. Valid friend image post without thumbnail (fallback to imageURL)
        let validPostNoThumb = Post(
            id: UUID(),
            author: friend,
            imageURL: URL(string: "https://example.com/friend_nothumb.jpg")!,
            thumbnailURL: nil,
            mediaType: .image,
            mentions: []
        )
        await syncService.syncLatestFriendPhoto(post: validPostNoThumb, currentUserId: currentUserId)
        let loadedNoThumb = cacheService.loadLatestFriendPhoto()
        XCTAssertEqual(loadedNoThumb?.postId, validPostNoThumb.id)
        if let loadedNoThumb, let cachedURL = cacheService.cachedImageURL(for: loadedNoThumb) {
            try? FileManager.default.removeItem(at: cachedURL)
        }
    }

    func testSyncStreak() {
        let syncService = WidgetDataSyncService()
        let cacheService = WidgetCacheService()

        let streak = StreakSummary(currentStreak: 10, hasTodayPhoto: true)
        syncService.syncStreak(streak)

        let loaded = cacheService.loadStreak()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.currentStreak, 10)
        XCTAssertEqual(loaded?.hasTodayPhoto, true)
    }

    func testSyncFriendRequests() {
        let syncService = WidgetDataSyncService()
        let cacheService = WidgetCacheService()

        let req = WidgetFriendRequestPreviewInput(
            id: UUID(),
            requesterName: "Sarah",
            requesterUsername: "sarah_p",
            avatarURL: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        syncService.syncFriendRequests([req])

        let loaded = cacheService.loadFriendRequests()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.pendingCount, 1)
        XCTAssertEqual(loaded?.requests.first?.requesterName, "Sarah")
        XCTAssertEqual(loaded?.requests.first?.requesterUsername, "sarah_p")
    }

    func testClearAllAndSharedServices() {
        let syncService = WidgetDataSyncService.shared
        let cacheService = WidgetCacheService.shared

        XCTAssertNotNil(syncService)
        XCTAssertNotNil(cacheService)

        syncService.clearAll()
    }
}
