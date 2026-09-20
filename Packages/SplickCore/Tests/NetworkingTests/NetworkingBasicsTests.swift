import XCTest
@testable import Networking
@testable import Common

final class NetworkingBasicsTests: XCTestCase {
    struct TestRequestDTO: Codable {
        let name: String
        let score: Int
    }

    struct TestEndpoint: APIEndpoint {
        var path: String = "/v1/test"
        var method: HTTPMethod = .post
        var headers: [String: String]? = ["X-Custom": "SplickHeader"]
        var queryItems: [URLQueryItem]? = [URLQueryItem(name: "filter", value: "active")]
        var body: Encodable? = TestRequestDTO(name: "tester", score: 100)
        var requiresAuth: Bool = true
        var sendsRefreshTokenHeader: Bool = true
    }

    func testEndpointURLRequestCreation() throws {
        let endpoint = TestEndpoint()
        let request = try endpoint.asURLRequest(baseURL: "https://api.splick.app")

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "SplickHeader")
        XCTAssertTrue(request.url?.absoluteString.contains("/v1/test?filter=active") == true)
        XCTAssertNotNil(request.httpBody)
    }

    func testHTTPMethods() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
    }

    func testTokenProviderActor() async {
        let provider = InMemoryTokenProvider()
        let initialAccess = await provider.accessToken()
        let initialRefresh = await provider.refreshToken()
        XCTAssertNil(initialAccess)
        XCTAssertNil(initialRefresh)

        await provider.updateTokens(access: "acc123", refresh: "ref123")
        let updatedAccess = await provider.accessToken()
        let updatedRefresh = await provider.refreshToken()
        XCTAssertEqual(updatedAccess, "acc123")
        XCTAssertEqual(updatedRefresh, "ref123")

        await provider.clearTokens()
        let clearedAccess = await provider.accessToken()
        let clearedRefresh = await provider.refreshToken()
        XCTAssertNil(clearedAccess)
        XCTAssertNil(clearedRefresh)
    }

    func testTokenRefreshCoordinator() async throws {
        let coordinator = TokenRefreshCoordinator()
        
        // Before configuring
        do {
            try await coordinator.refreshSession()
            XCTFail("Should fail before configuration")
        } catch {
            XCTAssertTrue(error is AuthError)
        }

        let lock = NSLock()
        var refreshCallCount = 0
        coordinator.configure {
            lock.lock()
            refreshCallCount += 1
            lock.unlock()
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // Concurrent requests share in-flight refresh (single-flight)
        async let r1: Void = coordinator.refreshSession()
        async let r2: Void = coordinator.refreshSession()
        _ = try await (r1, r2)

        lock.lock()
        let finalCount = refreshCallCount
        lock.unlock()
        XCTAssertEqual(finalCount, 1)
    }

    func testAPIResponseDecoding() throws {
        struct Payload: Codable, Equatable {
            let id: String
        }

        let json = """
        {
            "data": { "id": "123" },
            "message": "success",
            "timestamp": "2026-09-19T20:00:00Z"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.apiDecoder.decode(APIResponse<Payload>.self, from: json)
        XCTAssertEqual(response.data.id, "123")
        XCTAssertEqual(response.message, "success")
    }

    func testPaginatedResponseDecoding() throws {
        struct Item: Codable, Equatable {
            let value: Int
        }

        let json = """
        {
            "items": [{ "value": 1 }, { "value": 2 }],
            "page": 1,
            "total_pages": 5,
            "total_items": 10,
            "has_next": true
        }
        """.data(using: .utf8)!

        let paginated = try JSONDecoder.apiDecoder.decode(PaginatedResponse<Item>.self, from: json)
        XCTAssertEqual(paginated.items.count, 2)
        XCTAssertEqual(paginated.page, 1)
        XCTAssertEqual(paginated.totalPages, 5)
        XCTAssertTrue(paginated.hasNext)
    }

    func testAPIErrorBodyDecoding() throws {
        let json = """
        {
            "status": 401,
            "error": "UNAUTHORIZED",
            "message": "Token expired",
            "trace_id": "trace-999"
        }
        """.data(using: .utf8)!

        let err = try JSONDecoder.apiDecoder.decode(APIErrorBody.self, from: json)
        XCTAssertEqual(err.status, 401)
        XCTAssertEqual(err.error, "UNAUTHORIZED")
        XCTAssertEqual(err.message, "Token expired")
        XCTAssertEqual(err.traceId, "trace-999")
    }
}
