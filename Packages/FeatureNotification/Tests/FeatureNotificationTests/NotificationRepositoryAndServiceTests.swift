import XCTest
import Networking
import SplickDomain
import Common
@testable import FeatureNotification

// MARK: - Test-only MockAPIClient

actor TestMockAPIClient: APIClientProtocol {
    var shouldFail: Bool = false
    var failureError: NetworkError = .serverError(statusCode: 500)
    private var responses: [String: Any] = [:]
    var requestLog: [(method: String, path: String)] = []

    func register<T: Decodable>(path: String, response: T) {
        responses[path] = response
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestLog.append((method: endpoint.method.rawValue, path: endpoint.path))
        if shouldFail { throw failureError }
        guard let response = responses[endpoint.path] as? T else {
            throw NetworkError.notFound
        }
        return response
    }

    func request(_ endpoint: APIEndpoint) async throws {
        requestLog.append((method: endpoint.method.rawValue, path: endpoint.path))
        if shouldFail { throw failureError }
    }

    func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T {
        requestLog.append((method: "UPLOAD", path: endpoint.path))
        if shouldFail { throw failureError }
        guard let response = responses[endpoint.path] as? T else {
            throw NetworkError.notFound
        }
        return response
    }
}

// MARK: - NotificationRepository Tests

final class NotificationRepositoryTests: XCTestCase {
    private var apiClient: TestMockAPIClient!
    private var repository: NotificationRepository!

    override func setUp() {
        super.setUp()
        apiClient = TestMockAPIClient()
        repository = NotificationRepository(apiClient: apiClient)
    }

    func testFetchNotificationsSuccess() async throws {
        let notifId = UUID()
        let dto = NotificationResponseDTO(
            id: notifId,
            type: "FRIEND_REQUEST_SENT",
            title: "Test Title",
            body: "Test Body",
            isRead: false,
            referenceId: nil,
            actorUserId: nil,
            actorAvatarUrl: nil,
            destination: nil,
            createdAt: Date()
        )
        await apiClient.register(path: "/v1/notifications", response: [dto])

        let result = try await repository.fetchNotifications(page: 0, limit: 20, category: "SOCIAL")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, notifId)
        XCTAssertEqual(result[0].title, "Test Title")

        let log = await apiClient.requestLog
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0].path, "/v1/notifications")
        XCTAssertEqual(log[0].method, "GET")
    }

    func testMarkAsReadSuccess() async throws {
        let notifId = UUID()
        try await repository.markAsRead(id: notifId)

        let log = await apiClient.requestLog
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0].path, "/v1/notifications/\(notifId)/read")
        XCTAssertEqual(log[0].method, "POST")
    }

    func testMarkAsClickedSuccess() async throws {
        let notifId = UUID()
        try await repository.markAsClicked(id: notifId)

        let log = await apiClient.requestLog
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0].path, "/v1/notifications/\(notifId)/click")
        XCTAssertEqual(log[0].method, "POST")
    }

    func testMarkAllAsReadSuccess() async throws {
        try await repository.markAllAsRead()

        let log = await apiClient.requestLog
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0].path, "/v1/notifications/read-all")
        XCTAssertEqual(log[0].method, "POST")
    }

    func testMarkInboxSeenSuccess() async throws {
        try await repository.markInboxSeen()

        let log = await apiClient.requestLog
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0].path, "/v1/notifications/seen")
        XCTAssertEqual(log[0].method, "POST")
    }

    func testUnreadCountSuccess() async throws {
        let dto = UnreadCountDTO(count: 7)
        await apiClient.register(path: "/v1/notifications/unread-count", response: dto)

        let count = try await repository.unreadCount()
        XCTAssertEqual(count, 7)
    }

    func testFetchBadgeCountsSuccess() async throws {
        let dto = BadgeCountsDTO(notifications: 3, friends: 2, expenses: 1, messages: 4, inbox: 5)
        await apiClient.register(path: "/v1/notifications/badge-counts", response: dto)

        let counts = try await repository.fetchBadgeCounts()
        XCTAssertEqual(counts.notifications, 3)
        XCTAssertEqual(counts.friends, 2)
        XCTAssertEqual(counts.expenses, 1)
        XCTAssertEqual(counts.messages, 4)
        XCTAssertEqual(counts.inbox, 5)
    }

    func testRegisterDeviceTokenSuccess() async throws {
        try await repository.registerDeviceToken(
            token: "device-tok-999",
            bundleId: "com.splick.app",
            environment: "SANDBOX"
        )

        let log = await apiClient.requestLog
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0].path, "/v1/devices")
        XCTAssertEqual(log[0].method, "POST")
    }

    func testUnregisterDeviceTokenSuccess() async throws {
        try await repository.unregisterDeviceToken(token: "tok-to-remove")

        let log = await apiClient.requestLog
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0].path, "/v1/devices/tok-to-remove")
        XCTAssertEqual(log[0].method, "DELETE")
    }
}

// MARK: - DeviceTokenService Tests

private final class MockRegisterPushDeviceTokenUseCase: RegisterPushDeviceTokenUseCaseProtocol, @unchecked Sendable {
    var lastToken: String?
    var lastBundleId: String?
    var lastEnvironment: String?
    var errorToThrow: Error?

    func execute(token: String, bundleId: String, environment: String) async throws {
        if let error = errorToThrow { throw error }
        lastToken = token
        lastBundleId = bundleId
        lastEnvironment = environment
    }
}

private final class MockUnregisterPushDeviceTokenUseCase: UnregisterPushDeviceTokenUseCaseProtocol, @unchecked Sendable {
    var lastToken: String?
    var errorToThrow: Error?

    func execute(token: String) async throws {
        if let error = errorToThrow { throw error }
        lastToken = token
    }
}

final class DeviceTokenServiceTests: XCTestCase {
    func testRegisterDelegatesToUseCase() async throws {
        let registerUC = MockRegisterPushDeviceTokenUseCase()
        let unregisterUC = MockUnregisterPushDeviceTokenUseCase()
        let service = DeviceTokenService(registerUseCase: registerUC, unregisterUseCase: unregisterUC)

        try await service.register(token: "token-1", bundleId: "com.splick.app", environment: "DEV")
        XCTAssertEqual(registerUC.lastToken, "token-1")
        XCTAssertEqual(registerUC.lastBundleId, "com.splick.app")
        XCTAssertEqual(registerUC.lastEnvironment, "DEV")
    }

    func testUnregisterDelegatesToUseCase() async throws {
        let registerUC = MockRegisterPushDeviceTokenUseCase()
        let unregisterUC = MockUnregisterPushDeviceTokenUseCase()
        let service = DeviceTokenService(registerUseCase: registerUC, unregisterUseCase: unregisterUC)

        try await service.unregister(token: "token-2")
        XCTAssertEqual(unregisterUC.lastToken, "token-2")
    }
}

// MARK: - BadgeCountService Tests

private final class MockFetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol, @unchecked Sendable {
    var countsToReturn = TabBadgeCounts(notifications: 5, friends: 4, expenses: 3, messages: 2, inbox: 1)
    var errorToThrow: Error?
    var executeCallCount = 0

    func execute() async throws -> TabBadgeCounts {
        executeCallCount += 1
        if let error = errorToThrow { throw error }
        return countsToReturn
    }
}

@MainActor
final class BadgeCountServiceTests: XCTestCase {
    func testInitialCountsAreZero() {
        let useCase = MockFetchBadgeCountsUseCase()
        let service = BadgeCountService(fetchBadgeCountsUseCase: useCase)
        XCTAssertEqual(service.counts.total, 0)
        XCTAssertEqual(service.counts.inbox, 0)
    }

    func testApplyUpdatesCounts() {
        let useCase = MockFetchBadgeCountsUseCase()
        let service = BadgeCountService(fetchBadgeCountsUseCase: useCase)
        let newCounts = TabBadgeCounts(notifications: 10, friends: 2, expenses: 1, messages: 3, inbox: 5)

        service.apply(newCounts)
        XCTAssertEqual(service.counts.notifications, 10)
        XCTAssertEqual(service.counts.friends, 2)
        XCTAssertEqual(service.counts.inbox, 5)
    }

    func testClearUnseenInboxBadges() {
        let useCase = MockFetchBadgeCountsUseCase()
        let service = BadgeCountService(fetchBadgeCountsUseCase: useCase)
        let newCounts = TabBadgeCounts(notifications: 4, friends: 2, expenses: 1, messages: 3, inbox: 9)
        service.apply(newCounts)

        service.clearUnseenInboxBadges()
        XCTAssertEqual(service.counts.inbox, 0)
        XCTAssertEqual(service.counts.notifications, 4)
    }

    func testRefreshSuccessUpdatesCounts() async {
        let useCase = MockFetchBadgeCountsUseCase()
        let service = BadgeCountService(fetchBadgeCountsUseCase: useCase)

        await service.refresh(force: true)
        XCTAssertEqual(service.counts.notifications, 5)
        XCTAssertEqual(service.counts.friends, 4)
        XCTAssertEqual(useCase.executeCallCount, 1)
    }

    func testRefreshWithinFreshnessWindowSkipsFetch() async {
        let useCase = MockFetchBadgeCountsUseCase()
        let service = BadgeCountService(fetchBadgeCountsUseCase: useCase)

        // First refresh succeeds and sets lastFreshAt
        await service.refresh(force: true)
        XCTAssertEqual(useCase.executeCallCount, 1)

        // Immediate subsequent refresh without force should be skipped
        await service.refresh(force: false)
        XCTAssertEqual(useCase.executeCallCount, 1)

        // But with force: true, it bypasses the window
        await service.refresh(force: true)
        XCTAssertEqual(useCase.executeCallCount, 2)
    }

    func testRefreshErrorLogsAndRetainsPreviousCounts() async {
        let useCase = MockFetchBadgeCountsUseCase()
        let service = BadgeCountService(fetchBadgeCountsUseCase: useCase)
        let existing = TabBadgeCounts(notifications: 1, friends: 1, expenses: 1, messages: 1, inbox: 1)
        service.apply(existing)

        useCase.errorToThrow = NetworkError.serverError(statusCode: 500)
        await service.refresh(force: true)

        XCTAssertEqual(service.counts.notifications, 1)
        XCTAssertEqual(useCase.executeCallCount, 1)
    }

    func testConcurrentRefreshesShareSameTask() async {
        let useCase = MockFetchBadgeCountsUseCase()
        let service = BadgeCountService(fetchBadgeCountsUseCase: useCase)

        async let r1: Void = service.refresh(force: true)
        async let r2: Void = service.refresh(force: true)
        _ = await (r1, r2)

        XCTAssertEqual(useCase.executeCallCount, 1)
    }

    func testStartAndStopPolling() async {
        let useCase = MockFetchBadgeCountsUseCase()
        let service = BadgeCountService(
            fetchBadgeCountsUseCase: useCase,
            pollInterval: .milliseconds(50)
        )

        service.startPolling()
        // Calling startPolling again while already polling is a no-op
        service.startPolling()

        // Wait slightly for poll interval to tick once
        try? await Task.sleep(for: .milliseconds(120))
        service.stopPolling()

        // Calling stopPolling again is safe
        service.stopPolling()
        XCTAssertGreaterThanOrEqual(useCase.executeCallCount, 1)
    }
}
