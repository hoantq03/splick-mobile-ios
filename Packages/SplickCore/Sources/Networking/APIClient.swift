import Foundation
import Common

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func request(_ endpoint: APIEndpoint) async throws
    func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T
}

public final class APIClient: APIClientProtocol, Sendable {
    private let session: URLSession
    private let baseURL: String
    private let tokenProvider: TokenProvider
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        baseURL: String = AppConstants.API.baseURL,
        tokenProvider: TokenProvider,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session
        self.decoder = .apiDecoder
        self.encoder = .apiEncoder
    }

    public func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await performRequest(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Log.error("Decoding failed: \(error)", category: .network)
            throw NetworkError.decodingFailed
        }
    }

    public func request(_ endpoint: APIEndpoint) async throws {
        _ = try await performRequest(endpoint)
    }

    public func upload<T: Decodable>(
        _ endpoint: APIEndpoint,
        data: Data,
        mimeType: String
    ) async throws -> T {
        var request = try endpoint.asURLRequest(baseURL: baseURL, encoder: encoder)
        request = try await applyAuth(to: request, requiresAuth: endpoint.requiresAuth)

        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: responseData)
    }

    // MARK: - Private

    private func performRequest(_ endpoint: APIEndpoint) async throws -> Data {
        var request = try endpoint.asURLRequest(baseURL: baseURL, encoder: encoder)
        request = try await applyAuth(to: request, requiresAuth: endpoint.requiresAuth)

        Log.debug("\(endpoint.method.rawValue) \(endpoint.path)", category: .network)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        }

        try validateResponse(response)
        return data
    }

    private func applyAuth(to request: URLRequest, requiresAuth: Bool) async throws -> URLRequest {
        guard requiresAuth else { return request }

        guard let token = await tokenProvider.accessToken() else {
            throw NetworkError.unauthorized
        }

        var authedRequest = request
        authedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authedRequest
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 429:
            throw NetworkError.rateLimited
        case 500...599:
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw NetworkError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
