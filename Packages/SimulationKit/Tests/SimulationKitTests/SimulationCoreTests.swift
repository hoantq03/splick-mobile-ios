import XCTest
import Networking
import Storage
import Common
import SplickDomain
@testable import SimulationKit

// MARK: - MockTokenProvider Tests

final class MockTokenProviderTests: XCTestCase {
    func testTokenProviderLifecycle() async {
        let provider = MockTokenProvider(accessToken: "access1", refreshToken: "refresh1")

        let initialAccess = await provider.accessToken()
        let initialRefresh = await provider.refreshToken()
        XCTAssertEqual(initialAccess, "access1")
        XCTAssertEqual(initialRefresh, "refresh1")

        await provider.updateTokens(access: "access2", refresh: "refresh2")
        let updatedAccess = await provider.accessToken()
        let updatedRefresh = await provider.refreshToken()
        XCTAssertEqual(updatedAccess, "access2")
        XCTAssertEqual(updatedRefresh, "refresh2")

        await provider.clearTokens()
        let clearedAccess = await provider.accessToken()
        let clearedRefresh = await provider.refreshToken()
        XCTAssertNil(clearedAccess)
        XCTAssertNil(clearedRefresh)
    }
}

// MARK: - MockAPIClient Tests

private struct DummyEndpoint: APIEndpoint {
    let path: String
    let method: HTTPMethod
    var body: Encodable? = nil
}

private struct DummyResponse: Codable, Equatable {
    let message: String
}

final class MockAPIClientTests: XCTestCase {
    func testMockAPIClientSuccessAnd204() async throws {
        let client = MockAPIClient(delay: .zero)
        let endpoint = DummyEndpoint(path: "/v1/test", method: .get)
        let expected = DummyResponse(message: "hello")

        await client.register(path: "/v1/test", response: expected)
        let result: DummyResponse = try await client.request(endpoint)
        XCTAssertEqual(result, expected)

        // Test 204 request without response
        let postEndpoint = DummyEndpoint(path: "/v1/action", method: .post)
        try await client.request(postEndpoint)

        let log = await client.requestLog
        XCTAssertEqual(log.count, 2)
        XCTAssertEqual(log[0].path, "/v1/test")
        XCTAssertEqual(log[1].path, "/v1/action")
    }

    func testMockAPIClientUpload() async throws {
        let client = MockAPIClient(delay: .zero)
        let uploadEndpoint = DummyEndpoint(path: "/v1/upload", method: .post)
        let expected = DummyResponse(message: "uploaded")

        await client.register(path: "/v1/upload", response: expected)
        let result: DummyResponse = try await client.upload(
            uploadEndpoint,
            data: Data([0x01, 0x02]),
            mimeType: "image/jpeg"
        )
        XCTAssertEqual(result, expected)

        let log = await client.requestLog
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0].method, "UPLOAD")
    }

    func testMockAPIClientShouldFail() async {
        let client = MockAPIClient(
            delay: .zero,
            shouldFail: true,
            failureError: .serverError(statusCode: 503)
        )
        let endpoint = DummyEndpoint(path: "/v1/test", method: .get)

        do {
            let _: DummyResponse = try await client.request(endpoint)
            XCTFail("Expected failure")
        } catch NetworkError.serverError(let code, _) {
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMockAPIClientFailAfterN() async throws {
        let client = MockAPIClient(delay: .zero)
        await client.setFailAfter(1)
        let ep = DummyEndpoint(path: "/v1/test", method: .post)

        // First request succeeds
        try await client.request(ep)

        // Second request fails
        do {
            try await client.request(ep)
            XCTFail("Expected failure after 1 request")
        } catch {
            // Success
        }
    }

    func testMockAPIClientUnregisteredPathThrowsNotFound() async {
        let client = MockAPIClient(delay: .zero)
        let ep = DummyEndpoint(path: "/unregistered", method: .get)

        do {
            let _: DummyResponse = try await client.request(ep)
            XCTFail("Expected notFound")
        } catch NetworkError.notFound {
            // Success
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMockAPIClientReset() async throws {
        let client = MockAPIClient(delay: .zero)
        await client.setFailAfter(1)
        let ep = DummyEndpoint(path: "/v1/test", method: .post)
        try await client.request(ep)

        await client.reset()
        let log = await client.requestLog
        XCTAssertTrue(log.isEmpty)
    }
}

// MARK: - MockKeychainService Tests

final class MockKeychainServiceTests: XCTestCase {
    func testKeychainDataOperations() throws {
        let logger = StateLogger(module: "KeychainTest", printToConsole: false)
        let keychain = MockKeychainService(logger: logger)
        let testData = Data([0xDE, 0xAD, 0xBE, 0xEF])

        XCTAssertNil(try keychain.load(for: "key1"))

        try keychain.save(testData, for: "key1")
        XCTAssertEqual(try keychain.load(for: "key1"), testData)

        try keychain.delete(for: "key1")
        XCTAssertNil(try keychain.load(for: "key1"))
    }

    func testKeychainStringOperations() throws {
        let keychain = MockKeychainService(logger: nil)

        XCTAssertNil(try keychain.loadString(for: "str_key"))

        try keychain.saveString("secret_value", for: "str_key")
        XCTAssertEqual(try keychain.loadString(for: "str_key"), "secret_value")

        keychain.reset()
        XCTAssertNil(try keychain.loadString(for: "str_key"))
    }
}

// MARK: - StateLogger Tests

final class StateLoggerTests: XCTestCase {
    func testStateLoggerLogging() {
        let logger = StateLogger(module: "TestMod", printToConsole: false)
        XCTAssertTrue(logger.logs.isEmpty)

        logger.log("Simple message")
        XCTAssertEqual(logger.logs.count, 1)
        XCTAssertEqual(logger.logs[0].module, "TestMod")
        XCTAssertEqual(logger.logs[0].message, "Simple message")

        logger.stateTransition(from: "idle", to: "loading", detail: "refreshing")
        logger.stateTransition(from: "loading", to: "success", detail: nil as String?)
        XCTAssertEqual(logger.logs.count, 3)

        logger.apiCall(method: "GET", path: "/v1/feed", statusCode: 200, duration: .milliseconds(50))
        logger.apiCall(method: "POST", path: "/v1/post", statusCode: 201)
        XCTAssertEqual(logger.logs.count, 5)

        logger.success("All good")
        logger.failure("Something broke")
        XCTAssertEqual(logger.logs.count, 7)

        logger.separator()
        logger.clear()
        XCTAssertTrue(logger.logs.isEmpty)
    }
}

// MARK: - SimulationContainer Tests

final class SimulationContainerTests: XCTestCase {
    func testContainerInitializationAndSeeding() async {
        let container = SimulationContainer(loggerModule: "SimTest")
        XCTAssertNotNil(container.logger)
        XCTAssertNotNil(container.mockAPI)
        XCTAssertNotNil(container.mockTokenProvider)
        XCTAssertNotNil(container.mockKeychain)
        XCTAssertNotNil(container.feedRepository)
        XCTAssertNotNil(container.friendsRepository)
        XCTAssertNotNil(container.expenseRepository)
        XCTAssertNotNil(container.notificationRepository)
        XCTAssertNotNil(container.mediaRepository)

        // Verify all use cases are created
        XCTAssertNotNil(container.fetchFeedUseCase)
        XCTAssertNotNil(container.reactToPostUseCase)
        XCTAssertNotNil(container.deletePostUseCase)
        XCTAssertNotNil(container.createPostUseCase)
        XCTAssertNotNil(container.fetchFriendsUseCase)
        XCTAssertNotNil(container.fetchMyFriendsUseCase)
        XCTAssertNotNil(container.searchUsersUseCase)
        XCTAssertNotNil(container.fetchMyGroupsUseCase)
        XCTAssertNotNil(container.addFriendUseCase)
        XCTAssertNotNil(container.joinGroupUseCase)
        XCTAssertNotNil(container.fetchExpensesUseCase)
        XCTAssertNotNil(container.createExpenseUseCase)
        XCTAssertNotNil(container.fetchDebtSummaryUseCase)
        XCTAssertNotNil(container.fetchMonthlySummaryUseCase)
        XCTAssertNotNil(container.fetchNotificationsUseCase)
        XCTAssertNotNil(container.markNotificationReadUseCase)
        XCTAssertNotNil(container.markNotificationClickedUseCase)
        XCTAssertNotNil(container.uploadMediaUseCase)
        XCTAssertNotNil(container.uploadUserAvatarUseCase)
        XCTAssertNotNil(container.uploadGroupAvatarUseCase)

        // Seed test data
        await container.seedTestData()
    }
}
