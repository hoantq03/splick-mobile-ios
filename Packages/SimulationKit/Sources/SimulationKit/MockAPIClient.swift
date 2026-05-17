import Foundation
import Networking
import Common

public actor MockAPIClient: APIClientProtocol {
    public var delay: Duration
    public var shouldFail: Bool
    public var failureError: NetworkError
    public var requestLog: [(method: String, path: String, timestamp: Date)] = []

    private var responses: [String: Any] = [:]
    private var requestCount: Int = 0
    private var failAfterN: Int?

    public init(
        delay: Duration = .milliseconds(300),
        shouldFail: Bool = false,
        failureError: NetworkError = .serverError(statusCode: 500)
    ) {
        self.delay = delay
        self.shouldFail = shouldFail
        self.failureError = failureError
    }

    public func register<T: Decodable>(path: String, response: T) {
        responses[path] = response
    }

    public func setFailAfter(_ n: Int) {
        failAfterN = n
    }

    public func reset() {
        requestLog = []
        requestCount = 0
        shouldFail = false
        failAfterN = nil
    }

    public func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        try await Task.sleep(for: delay)

        requestCount += 1
        requestLog.append((
            method: endpoint.method.rawValue,
            path: endpoint.path,
            timestamp: .now
        ))

        if shouldFail {
            throw failureError
        }

        if let failAfterN, requestCount > failAfterN {
            throw failureError
        }

        guard let response = responses[endpoint.path] as? T else {
            Log.warning("[MockAPI] No registered response for: \(endpoint.path)", category: .network)
            throw NetworkError.notFound
        }

        Log.debug("[MockAPI] \(endpoint.method.rawValue) \(endpoint.path) → 200 OK", category: .network)
        return response
    }

    public func request(_ endpoint: APIEndpoint) async throws {
        try await Task.sleep(for: delay)

        requestCount += 1
        requestLog.append((
            method: endpoint.method.rawValue,
            path: endpoint.path,
            timestamp: .now
        ))

        if shouldFail { throw failureError }
        if let failAfterN, requestCount > failAfterN { throw failureError }

        Log.debug("[MockAPI] \(endpoint.method.rawValue) \(endpoint.path) → 204 No Content", category: .network)
    }

    public func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T {
        try await Task.sleep(for: delay)

        requestCount += 1
        requestLog.append((
            method: "UPLOAD",
            path: endpoint.path,
            timestamp: .now
        ))

        if shouldFail { throw failureError }

        guard let response = responses[endpoint.path] as? T else {
            throw NetworkError.notFound
        }

        Log.debug("[MockAPI] UPLOAD \(endpoint.path) (\(data.count) bytes) → 200 OK", category: .network)
        return response
    }
}
