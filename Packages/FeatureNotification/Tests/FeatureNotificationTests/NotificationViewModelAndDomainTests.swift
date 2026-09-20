import XCTest
import SplickDomain
import Storage
import Common
import Localization
import Networking
@testable import FeatureNotification

// MARK: - Mock Friend Request Inbox

final class MockFriendRequestInbox: FriendRequestInboxResponding, @unchecked Sendable {
    var acceptedIds: [UUID] = []
    var rejectedIds: [UUID] = []
    var pendingResult = PendingIncomingFriendRequests(requestIdByRequester: [:])
    var errorToThrow: Error?

    func acceptIncomingRequest(requestId: UUID) async throws {
        if let error = errorToThrow { throw error }
        acceptedIds.append(requestId)
    }

    func rejectIncomingRequest(requestId: UUID) async throws {
        if let error = errorToThrow { throw error }
        rejectedIds.append(requestId)
    }

    func pendingIncomingRequests() async throws -> PendingIncomingFriendRequests {
        if let error = errorToThrow { throw error }
        return pendingResult
    }
}

// MARK: - Mock Notification Repository with Configurable Results

private final class ConfigurableNotificationRepository: NotificationRepositoryProtocol, @unchecked Sendable {
    var notificationsToReturn: [AppNotification] = []
    var errorToThrow: Error?
    var fetchCallCount = 0
    var lastPage: Int = 0
    var lastCategory: String?
    var readIds: [UUID] = []
    var clickedIds: [UUID] = []
    var markClickedErrorToThrow: Error?
    var markReadErrorToThrow: Error?
    var markAllReadErrorToThrow: Error?
    var markInboxSeenErrorToThrow: Error?

    func fetchNotifications(page: Int, limit: Int, category: String?) async throws -> [AppNotification] {
        fetchCallCount += 1
        lastPage = page
        lastCategory = category
        if let error = errorToThrow { throw error }
        return notificationsToReturn
    }

    func markAsRead(id: UUID) async throws {
        if let error = markReadErrorToThrow { throw error }
        readIds.append(id)
    }

    func markAsClicked(id: UUID) async throws {
        if let error = markClickedErrorToThrow { throw error }
        clickedIds.append(id)
    }

    func markAllAsRead() async throws {
        if let error = markAllReadErrorToThrow { throw error }
    }

    func markInboxSeen() async throws {
        if let error = markInboxSeenErrorToThrow { throw error }
    }

    func unreadCount() async throws -> Int {
        notificationsToReturn.filter { !$0.isRead }.count
    }

    func fetchBadgeCounts() async throws -> TabBadgeCounts {
        .zero
    }

    func registerDeviceToken(token: String, bundleId: String, environment: String) async throws {}
    func unregisterDeviceToken(token: String) async throws {}
}

// MARK: - Extended NotificationListViewModel Tests

@MainActor
final class NotificationListViewModelExtendedTests: XCTestCase {
    private var repo: ConfigurableNotificationRepository!
    private var fetchUseCase: FetchNotificationsUseCase!
    private var markReadUseCase: MarkNotificationReadUseCase!
    private var markClickedUseCase: MarkNotificationClickedUseCase!
    private var markInboxSeenUseCase: MarkInboxSeenUseCase!
    private var languageService: LanguageService!
    private var userDefaults: MockUserDefaultsService!
    private var friendInbox: MockFriendRequestInbox!

    override func setUp() {
        super.setUp()
        repo = ConfigurableNotificationRepository()
        fetchUseCase = FetchNotificationsUseCase(repository: repo, pageSize: 2)
        markReadUseCase = MarkNotificationReadUseCase(repository: repo)
        markClickedUseCase = MarkNotificationClickedUseCase(repository: repo)
        markInboxSeenUseCase = MarkInboxSeenUseCase(repository: repo)
        userDefaults = MockUserDefaultsService()
        languageService = LanguageService(userDefaults: userDefaults)
        friendInbox = MockFriendRequestInbox()
    }

    private func makeVM(
        onBadgeCountsChanged: (() async -> Void)? = nil,
        onMarkAllReadCompleted: (() async -> Void)? = nil
    ) -> NotificationListViewModel {
        NotificationListViewModel(
            fetchNotificationsUseCase: fetchUseCase,
            markReadUseCase: markReadUseCase,
            markClickedUseCase: markClickedUseCase,
            markInboxSeenUseCase: markInboxSeenUseCase,
            languageService: languageService,
            friendRequestInbox: friendInbox,
            userDefaultsService: userDefaults,
            onBadgeCountsChanged: onBadgeCountsChanged,
            onMarkAllReadCompleted: onMarkAllReadCompleted
        )
    }

    func testShowsInitialLoading() {
        let vm = makeVM()
        XCTAssertFalse(vm.showsInitialLoading)
        vm.state = .loading
        XCTAssertTrue(vm.showsInitialLoading)
    }

    func testSelectCategoryAllDoesNothing() async {
        let vm = makeVM()
        await vm.selectCategory(.all)
        XCTAssertEqual(vm.selectedCategory, .all)
    }

    func testSelectCategoryTogglesBackToAll() async {
        let vm = makeVM()
        await vm.selectCategory(.expenses)
        XCTAssertEqual(vm.selectedCategory, .expenses)

        // Select again toggles to .all
        await vm.selectCategory(.expenses)
        XCTAssertEqual(vm.selectedCategory, .all)
    }

    func testReloadOnOpenWhenNotificationsNotEmptyTriggersPullToRefresh() async {
        let notif = AppNotification(
            id: UUID(),
            type: .system,
            title: "Hello",
            body: "World",
            isRead: false,
            createdAt: Date()
        )
        repo.notificationsToReturn = [notif]

        let vm = makeVM()
        await vm.reloadOnOpen()
        XCTAssertEqual(vm.notifications.count, 1)

        // Second call triggers pullToRefresh path
        await vm.reloadOnOpen()
        XCTAssertEqual(vm.notifications.count, 1)
    }

    func testLoadMorePagination() async {
        let firstBatch = (0..<20).map { i in
            AppNotification(id: UUID(), type: .system, title: "\(i)", body: "", isRead: true, createdAt: Date())
        }
        let n3 = AppNotification(id: UUID(), type: .system, title: "next", body: "", isRead: true, createdAt: Date())

        repo.notificationsToReturn = firstBatch // count >= pageSize (20), so hasMorePages is true
        let vm = makeVM()
        await vm.load()

        XCTAssertEqual(vm.notifications.count, 20)
        XCTAssertTrue(vm.hasMorePages)

        // loadMoreIfNeeded when current is not last -> does nothing
        await vm.loadMoreIfNeeded(current: firstBatch[0])
        XCTAssertEqual(vm.notifications.count, 20)

        // loadMoreIfNeeded when current is last -> loads more
        repo.notificationsToReturn = [n3] // count < pageSize, so hasMorePages becomes false
        await vm.loadMoreIfNeeded(current: firstBatch.last!)

        XCTAssertEqual(vm.notifications.count, 21)
        XCTAssertFalse(vm.hasMorePages)

        // Calling loadMore again when hasMorePages is false does nothing
        await vm.loadMore()
        XCTAssertEqual(vm.notifications.count, 21)
    }

    func testLoadMoreWhenEmptyBatchSetsHasMorePagesFalse() async {
        let firstBatch = (0..<20).map { i in
            AppNotification(id: UUID(), type: .system, title: "\(i)", body: "", isRead: true, createdAt: Date())
        }
        repo.notificationsToReturn = firstBatch

        let vm = makeVM()
        await vm.load()

        repo.notificationsToReturn = [] // empty batch
        await vm.loadMore()

        XCTAssertFalse(vm.hasMorePages)
    }

    func testLoadMoreCatchesError() async {
        let n1 = AppNotification(id: UUID(), type: .system, title: "1", body: "", isRead: true, createdAt: Date())
        let n2 = AppNotification(id: UUID(), type: .system, title: "2", body: "", isRead: true, createdAt: Date())
        repo.notificationsToReturn = [n1, n2]

        let vm = makeVM()
        await vm.load()

        repo.errorToThrow = NetworkError.serverError(statusCode: 500)
        await vm.loadMore()
        // Graceful error handling, count remains 2
        XCTAssertEqual(vm.notifications.count, 2)
    }

    func testPerformLoadErrors() async {
        let vm = makeVM()

        // 1. Initial load fails -> state becomes .failed
        repo.errorToThrow = NetworkError.noConnection
        await vm.load(isPullToRefresh: false)
        if case .failed = vm.state {
            // expected
        } else {
            XCTFail("Expected state to be failed")
        }

        // 2. Load succeeds with 1 item
        let notif = AppNotification(id: UUID(), type: .system, title: "1", body: "", isRead: false, createdAt: Date())
        repo.errorToThrow = nil
        repo.notificationsToReturn = [notif]
        await vm.load(isPullToRefresh: false)
        XCTAssertEqual(vm.notifications.count, 1)

        // 3. Pull-to-refresh fails while notifications exist -> retains .loaded state
        repo.errorToThrow = NetworkError.timeout
        await vm.load(isPullToRefresh: true)
        if case .loaded(let items) = vm.state {
            XCTAssertEqual(items.count, 1)
        } else {
            XCTFail("Expected state to remain loaded")
        }
    }

    func testHandleTapFallbackToMarkAsRead() async {
        let notif = AppNotification(id: UUID(), type: .system, title: "A", body: "B", isRead: false, createdAt: Date())
        repo.notificationsToReturn = [notif]

        var badgeChangedCalled = false
        let vm = makeVM(onBadgeCountsChanged: {
            badgeChangedCalled = true
        })
        await vm.load()

        // Make markClicked throw error, causing fallback to markAsRead
        repo.markClickedErrorToThrow = NetworkError.serverError(statusCode: 400)
        let target = await vm.handleTap(notif)
        XCTAssertEqual(target, notif.navigationTarget)
        XCTAssertEqual(repo.readIds, [notif.id])
        XCTAssertTrue(badgeChangedCalled)
    }

    func testMarkMessageNotificationsRead() async {
        let convoId = UUID()
        let refId = UUID()

        let matchingConvo = AppNotification(
            id: UUID(),
            type: .directMessage,
            title: "DM",
            body: "msg",
            isRead: false,
            destination: NotificationDestination(screen: .messages, postId: convoId),
            createdAt: Date()
        )
        let matchingRef = AppNotification(
            id: UUID(),
            type: .groupMessage,
            title: "Group",
            body: "msg",
            isRead: false,
            referenceId: refId,
            createdAt: Date()
        )
        let unmatchingType = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Friend",
            body: "",
            isRead: false,
            referenceId: convoId,
            createdAt: Date()
        )
        let alreadyRead = AppNotification(
            id: UUID(),
            type: .directMessage,
            title: "Read DM",
            body: "",
            isRead: true,
            referenceId: convoId,
            createdAt: Date()
        )

        repo.notificationsToReturn = [matchingConvo, matchingRef, unmatchingType, alreadyRead]

        var badgeCalled = false
        let vm = makeVM(onBadgeCountsChanged: { badgeCalled = true })
        vm.notifications = [matchingConvo, matchingRef, unmatchingType, alreadyRead]

        await vm.markMessageNotificationsRead(conversationId: convoId)
        XCTAssertTrue(repo.readIds.contains(matchingConvo.id))
        XCTAssertFalse(repo.readIds.contains(matchingRef.id))
        XCTAssertFalse(repo.readIds.contains(unmatchingType.id))
        XCTAssertTrue(badgeCalled)

        // Calling with an unknown id does nothing
        await vm.markMessageNotificationsRead(conversationId: UUID())
    }

    func testMarkAllAsReadWithCustomCompletion() async {
        let notif = AppNotification(id: UUID(), type: .system, title: "", body: "", isRead: false, createdAt: Date())
        repo.notificationsToReturn = [notif]

        var markAllCompletedCalled = false
        let vm = makeVM(onMarkAllReadCompleted: {
            markAllCompletedCalled = true
        })
        await vm.load()

        await vm.markAllAsRead()
        XCTAssertTrue(markAllCompletedCalled)
        XCTAssertTrue(vm.notifications[0].isRead)
    }

    func testMarkAllAsReadErrorHandled() async {
        repo.markAllReadErrorToThrow = NetworkError.serverError(statusCode: 500)
        let vm = makeVM()
        await vm.markAllAsRead()
        // No crash
    }

    func testMarkInboxSeenErrorHandled() async {
        repo.markInboxSeenErrorToThrow = NetworkError.serverError(statusCode: 500)
        var badgeCalled = false
        let vm = makeVM(onBadgeCountsChanged: { badgeCalled = true })
        await vm.markInboxSeen()
        XCTAssertTrue(badgeCalled)
    }

    func testFriendRequestActionsAcceptAndReject() async {
        let requestId = UUID()
        let actorId = UUID()
        let notif = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "FR",
            body: "req",
            isRead: false,
            referenceId: requestId,
            actorUserId: actorId,
            createdAt: Date()
        )

        let req2Id = UUID()
        let notif2 = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "FR2",
            body: "",
            isRead: true,
            referenceId: req2Id,
            createdAt: Date()
        )

        friendInbox.pendingResult = PendingIncomingFriendRequests(requestIds: [requestId, req2Id], requesterIds: [actorId])
        repo.notificationsToReturn = [notif, notif2]

        let vm = makeVM()
        await vm.load()

        XCTAssertTrue(vm.showsFriendRequestActions(for: notif))
        XCTAssertFalse(vm.isProcessingFriendRequest(notif))
        XCTAssertNil(vm.friendRequestOutcome(for: notif))

        // Accept
        await vm.acceptFriendRequest(notif)
        XCTAssertEqual(friendInbox.acceptedIds, [requestId])
        XCTAssertEqual(vm.friendRequestOutcome(for: notif), .accepted)
        XCTAssertFalse(vm.showsFriendRequestActions(for: notif))

        // Outcome persisted to userDefaults
        vm.reloadFriendRequestOutcomes()
        XCTAssertEqual(vm.friendRequestOutcome(for: notif), .accepted)

        // Reject second request
        await vm.rejectFriendRequest(notif2)
        XCTAssertEqual(friendInbox.rejectedIds, [req2Id])
        XCTAssertEqual(vm.friendRequestOutcome(for: notif2), .rejected)
    }

    func testFriendRequestStaleErrors() async {
        let requestId = UUID()
        let notif = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "FR",
            body: "",
            isRead: false,
            referenceId: requestId,
            createdAt: Date()
        )
        let req2 = UUID()
        let notif2 = AppNotification(id: UUID(), type: .friendRequestSent, title: "", body: "", isRead: false, referenceId: req2, createdAt: Date())
        let req3 = UUID()
        let notif3 = AppNotification(id: UUID(), type: .friendRequestSent, title: "", body: "", isRead: false, referenceId: req3, createdAt: Date())

        friendInbox.pendingResult = PendingIncomingFriendRequests(requestIds: [requestId, req2, req3], requesterIds: [])
        repo.notificationsToReturn = [notif, notif2, notif3]

        let vm = makeVM()
        await vm.load()

        // 1. NotFound error -> treated as stale
        friendInbox.errorToThrow = NetworkError.notFound
        await vm.acceptFriendRequest(notif)
        XCTAssertFalse(vm.showsFriendRequestActions(for: notif))

        // 2. APIError with "already" -> treated as stale
        friendInbox.errorToThrow = NetworkError.apiError(code: "ALREADY_ACCEPTED", message: "Conflict")
        await vm.acceptFriendRequest(notif2)
        XCTAssertFalse(vm.showsFriendRequestActions(for: notif2))

        // 3. Generic error -> sets friendRequestAlertMessage
        friendInbox.errorToThrow = NetworkError.serverError(statusCode: 500)
        await vm.acceptFriendRequest(notif3)
        XCTAssertNotNil(vm.friendRequestAlertMessage)
    }
}

// MARK: - FriendRequestInboxOutcomePersistence Tests

final class FriendRequestInboxOutcomePersistenceTests: XCTestCase {
    func testLoadFromNilDefaultsReturnsEmpty() {
        let result = FriendRequestInboxOutcomePersistence.load(from: nil)
        XCTAssertTrue(result.isEmpty)
    }

    func testSaveAndLoadRoundtrip() {
        let defaults = MockUserDefaultsService()
        let id1 = UUID()
        let id2 = UUID()
        let outcomes: [UUID: FriendRequestInboxOutcome] = [
            id1: .accepted,
            id2: .rejected,
        ]

        FriendRequestInboxOutcomePersistence.save(outcomes, to: defaults)
        let loaded = FriendRequestInboxOutcomePersistence.load(from: defaults)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[id1], .accepted)
        XCTAssertEqual(loaded[id2], .rejected)
    }

    func testLoadIgnoresCorruptKeysAndValues() {
        let defaults = MockUserDefaultsService()
        let validId = UUID()
        let corrupt: [String: String] = [
            "not-a-uuid": "accepted",
            validId.uuidString: "unknown_status",
        ]
        defaults.set(corrupt, for: AppConstants.UserDefaults.processedFriendRequestOutcomes)

        let loaded = FriendRequestInboxOutcomePersistence.load(from: defaults)
        XCTAssertTrue(loaded.isEmpty)
    }
}

// MARK: - NotificationTimeSection Tests

final class NotificationTimeSectionTests: XCTestCase {
    func testAllL10nKeysExist() {
        for section in NotificationTimeSection.allCases {
            XCTAssertNotNil(section.l10nKey)
        }
    }

    func testResolveDates() {
        let calendar = Calendar.current
        let now = Date()

        // Future date (< 0) -> .today
        let future = calendar.date(byAdding: .day, value: 2, to: now)!
        XCTAssertEqual(NotificationTimeSection.resolve(for: future, calendar: calendar, now: now), .today)

        // Today (0) -> .today
        XCTAssertEqual(NotificationTimeSection.resolve(for: now, calendar: calendar, now: now), .today)

        // 1 day ago -> .yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(NotificationTimeSection.resolve(for: yesterday, calendar: calendar, now: now), .yesterday)

        // 3 days ago -> .pastWeek
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        XCTAssertEqual(NotificationTimeSection.resolve(for: threeDaysAgo, calendar: calendar, now: now), .pastWeek)

        // 10 days ago -> .pastMonth
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: now)!
        XCTAssertEqual(NotificationTimeSection.resolve(for: tenDaysAgo, calendar: calendar, now: now), .pastMonth)

        // 45 days ago -> .pastYear
        let fortyFiveDaysAgo = calendar.date(byAdding: .day, value: -45, to: now)!
        XCTAssertEqual(NotificationTimeSection.resolve(for: fortyFiveDaysAgo, calendar: calendar, now: now), .pastYear)
    }

    func testGroupedFromNotifications() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let n1 = AppNotification(id: UUID(), type: .system, title: "1", body: "", isRead: true, createdAt: now)
        let n2 = AppNotification(id: UUID(), type: .system, title: "2", body: "", isRead: false, createdAt: yesterday)

        let sections = NotificationListSection.grouped(from: [n1, n2])
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].id, .today)
        XCTAssertEqual(sections[0].notifications.count, 1)
        XCTAssertEqual(sections[1].id, .yesterday)
        XCTAssertEqual(sections[1].notifications.count, 1)

        let emptySections = NotificationListSection.grouped(from: [])
        XCTAssertTrue(emptySections.isEmpty)
    }
}

// MARK: - NotificationInboxViewModel Edge Cases Tests

@MainActor
final class NotificationInboxViewModelEdgeCasesTests: XCTestCase {
    func testFetchNotificationsErrorSetsErrorMessage() async {
        let repo = ConfigurableNotificationRepository()
        repo.errorToThrow = NetworkError.serverError(statusCode: 500)

        let vm = NotificationInboxViewModel(repository: repo)
        await vm.fetchNotifications()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func testMarkAsClickedWhenAlreadyReadDoesNothing() async {
        let repo = ConfigurableNotificationRepository()
        let notif = AppNotification(id: UUID(), type: .system, title: "", body: "", isRead: true, createdAt: Date())
        let vm = NotificationInboxViewModel(repository: repo)
        vm.notifications = [notif]

        await vm.markAsClicked(notification: notif)
        XCTAssertTrue(repo.readIds.isEmpty)
    }

    func testMarkAsClickedErrorHandled() async {
        let repo = ConfigurableNotificationRepository()
        repo.markReadErrorToThrow = NetworkError.timeout
        let notif = AppNotification(id: UUID(), type: .system, title: "", body: "", isRead: false, createdAt: Date())
        let vm = NotificationInboxViewModel(repository: repo)
        vm.notifications = [notif]

        await vm.markAsClicked(notification: notif)
        // No crash, notification remains unread
        XCTAssertFalse(vm.notifications[0].isRead)
    }
}

// MARK: - NotificationMapper & Endpoint Edge Cases

final class NotificationMapperAndEndpointEdgeCasesTests: XCTestCase {
    func testNotificationMapperUnknownTypeAndInvalidAvatarURL() {
        let dto = NotificationResponseDTO(
            id: UUID(),
            type: "FUTURE_UNKNOWN_TYPE",
            title: "T",
            body: "B",
            isRead: false,
            referenceId: nil,
            actorUserId: nil,
            actorAvatarUrl: "",
            destination: nil,
            createdAt: Date()
        )

        let domain = NotificationMapper.toNotification(dto)
        XCTAssertEqual(domain.type, .system)
        XCTAssertNil(domain.actorAvatarURL)
    }

    func testDeviceEndpointUnregisterBodyIsNil() {
        let endpoint = DeviceEndpoint.unregister(token: "my-token")
        XCTAssertNil(endpoint.body)
    }
}
