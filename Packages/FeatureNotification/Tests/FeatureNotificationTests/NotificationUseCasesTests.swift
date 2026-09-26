import XCTest
import SplickDomain
import Storage
@testable import FeatureNotification

final class MockNotificationRepository: NotificationRepositoryProtocol, @unchecked Sendable {
    var notifications: [AppNotification] = []
    var lastPage: Int?
    var lastLimit: Int?
    var lastCategory: String?
    var readIds: [UUID] = []
    var clickedIds: [UUID] = []
    var allReadMarked = false
    var inboxSeenMarked = false
    var registeredToken: String?
    var registeredBundleId: String?
    var registeredEnv: String?
    var unregisteredToken: String?

    func fetchNotifications(page: Int, limit: Int, category: String?) async throws -> [AppNotification] {
        lastPage = page
        lastLimit = limit
        lastCategory = category
        return notifications
    }

    func markAsRead(id: UUID) async throws {
        readIds.append(id)
    }

    func markAsClicked(id: UUID) async throws {
        clickedIds.append(id)
    }

    func markAllAsRead() async throws {
        allReadMarked = true
    }

    func markInboxSeen() async throws {
        inboxSeenMarked = true
    }

    func unreadCount() async throws -> Int {
        notifications.filter { !$0.isRead }.count
    }

    func fetchBadgeCounts() async throws -> TabBadgeCounts {
        TabBadgeCounts(notifications: 2, friends: 1, expenses: 3, messages: 4, inbox: 5)
    }

    func registerDeviceToken(token: String, bundleId: String, environment: String) async throws {
        registeredToken = token
        registeredBundleId = bundleId
        registeredEnv = environment
    }

    func unregisterDeviceToken(token: String) async throws {
        unregisteredToken = token
    }
}

final class NotificationUseCasesTests: XCTestCase {
    func testFetchNotificationsUseCaseFiltersMessaging() async throws {
        let repo = MockNotificationRepository()
        let notifSocial = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Friend",
            body: "Hi",
            isRead: false,
            createdAt: Date()
        )
        let notifMessage = AppNotification(
            id: UUID(),
            type: .directMessage,
            title: "Message",
            body: "Chat",
            isRead: false,
            createdAt: Date()
        )
        repo.notifications = [notifSocial, notifMessage]

        let useCase = FetchNotificationsUseCase(repository: repo, pageSize: 15)
        let results = try await useCase.execute(page: 1, category: .friends)

        XCTAssertEqual(repo.lastPage, 1)
        XCTAssertEqual(repo.lastLimit, 15)
        XCTAssertEqual(repo.lastCategory, NotificationListCategory.friends.queryValue)
        // Messaging notifications must be filtered out
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, notifSocial.id)

        // Default category overload
        _ = try await useCase.execute(page: 0)
        XCTAssertEqual(repo.lastPage, 0)
    }

    func testMarkNotificationReadAndClickedUseCases() async throws {
        let repo = MockNotificationRepository()
        let readUseCase = MarkNotificationReadUseCase(repository: repo)
        let clickUseCase = MarkNotificationClickedUseCase(repository: repo)
        let seenUseCase = MarkInboxSeenUseCase(repository: repo)

        let notifId = UUID()
        try await readUseCase.execute(id: notifId)
        XCTAssertEqual(repo.readIds, [notifId])

        try await readUseCase.markAllRead()
        XCTAssertTrue(repo.allReadMarked)

        try await clickUseCase.execute(id: notifId)
        XCTAssertEqual(repo.clickedIds, [notifId])

        try await seenUseCase.execute()
        XCTAssertTrue(repo.inboxSeenMarked)
    }

    func testRegisterAndUnregisterPushDeviceTokens() async throws {
        let repo = MockNotificationRepository()
        let registerUseCase = RegisterPushDeviceTokenUseCase(repository: repo)
        let unregisterUseCase = UnregisterPushDeviceTokenUseCase(repository: repo)

        try await registerUseCase.execute(
            token: "apns-token-abc",
            bundleId: "com.splick.app",
            environment: "DEVELOPMENT"
        )
        XCTAssertEqual(repo.registeredToken, "apns-token-abc")
        XCTAssertEqual(repo.registeredBundleId, "com.splick.app")
        XCTAssertEqual(repo.registeredEnv, "DEVELOPMENT")

        try await unregisterUseCase.execute(token: "apns-token-abc")
        XCTAssertEqual(repo.unregisteredToken, "apns-token-abc")
    }

    func testFetchBadgeCountsUseCaseAndTabBadgeCounts() async throws {
        let repo = MockNotificationRepository()
        let useCase = FetchBadgeCountsUseCase(repository: repo)

        let counts = try await useCase.execute()
        XCTAssertEqual(counts.notifications, 2)
        XCTAssertEqual(counts.friends, 1)
        XCTAssertEqual(counts.expenses, 3)
        XCTAssertEqual(counts.messages, 4)
        XCTAssertEqual(counts.inbox, 5)
        XCTAssertEqual(counts.total, 10)

        let clearedInbox = counts.clearingUnseenInboxBadges()
        XCTAssertEqual(clearedInbox.inbox, 0)
        XCTAssertEqual(clearedInbox.total, 10)

        let zero = TabBadgeCounts.zero
        XCTAssertEqual(zero.total, 0)
    }

    @MainActor
    func testNotificationInboxViewModel() async {
        let repo = MockNotificationRepository()
        let notif = AppNotification(
            id: UUID(),
            type: .system,
            title: "Welcome",
            body: "Welcome to Splick",
            isRead: false,
            createdAt: Date()
        )
        repo.notifications = [notif]

        let vm = NotificationInboxViewModel(repository: repo)
        XCTAssertTrue(vm.notifications.isEmpty)
        XCTAssertFalse(vm.isLoading)

        await vm.fetchNotifications()
        XCTAssertEqual(vm.notifications.count, 1)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)

        // Mark as clicked
        await vm.markAsClicked(notification: notif)
        XCTAssertEqual(repo.readIds, [notif.id])
        XCTAssertTrue(vm.notifications.first?.isRead ?? false)
    }
}

import Localization
import Common

final class MockUserDefaultsService: UserDefaultsServiceProtocol {
    private var storage: [String: Any] = [:]
    func set<T: Codable>(_ value: T, for key: String) { storage[key] = value }
    func get<T: Codable>(for key: String) -> T? { storage[key] as? T }
    func setBool(_ value: Bool, for key: String) { storage[key] = value }
    func getBool(for key: String) -> Bool { (storage[key] as? Bool) ?? false }
    func remove(for key: String) { storage.removeValue(forKey: key) }
}

@MainActor
final class NotificationListViewModelTests: XCTestCase {
    private var repo: MockNotificationRepository!
    private var fetchUseCase: FetchNotificationsUseCase!
    private var markReadUseCase: MarkNotificationReadUseCase!
    private var markClickedUseCase: MarkNotificationClickedUseCase!
    private var markInboxSeenUseCase: MarkInboxSeenUseCase!
    private var languageService: LanguageService!

    override func setUp() {
        super.setUp()
        repo = MockNotificationRepository()
        fetchUseCase = FetchNotificationsUseCase(repository: repo)
        markReadUseCase = MarkNotificationReadUseCase(repository: repo)
        markClickedUseCase = MarkNotificationClickedUseCase(repository: repo)
        markInboxSeenUseCase = MarkInboxSeenUseCase(repository: repo)
        let userDefaults = MockUserDefaultsService()
        languageService = LanguageService(userDefaults: userDefaults)
    }

    func testNotificationListViewModelFlow() async {
        let notif1 = AppNotification(
            id: UUID(),
            type: .system,
            title: "Update",
            body: "New features available",
            isRead: false,
            createdAt: Date()
        )
        let notif2 = AppNotification(
            id: UUID(),
            type: .expenseSplitBill,
            title: "Expense added",
            body: "Lunch with friends",
            isRead: true,
            createdAt: Date().addingTimeInterval(-3600)
        )
        repo.notifications = [notif1, notif2]

        let vm = NotificationListViewModel(
            fetchNotificationsUseCase: fetchUseCase,
            markReadUseCase: markReadUseCase,
            markClickedUseCase: markClickedUseCase,
            markInboxSeenUseCase: markInboxSeenUseCase,
            languageService: languageService
        )

        XCTAssertTrue(vm.notifications.isEmpty)
        XCTAssertEqual(vm.unreadCount, 0)

        await vm.reloadOnOpen()
        XCTAssertEqual(vm.notifications.count, 2)
        XCTAssertEqual(vm.unreadCount, 1)
        XCTAssertFalse(vm.notificationSections.isEmpty)

        // Test category selection
        await vm.selectCategory(.expenses)
        XCTAssertEqual(vm.selectedCategory, .expenses)

        // Test handle tap
        _ = await vm.handleTap(notif1)
        XCTAssertEqual(repo.clickedIds, [notif1.id])
        XCTAssertEqual(vm.unreadCount, 0)

        // Test mark all as read
        await vm.markAllAsRead()
        XCTAssertTrue(repo.allReadMarked)

        // Test mark inbox seen
        await vm.markInboxSeen()
        XCTAssertTrue(repo.inboxSeenMarked)
    }
}
