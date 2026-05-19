import Foundation
import Common

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func request(_ endpoint: APIEndpoint) async throws
    func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T
}

public final class APIClient: APIClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: String
    private let tokenProvider: TokenProvider
    private let tokenRefresher: TokenRefreshHandling?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        baseURL: String = AppConstants.API.baseURL,
        tokenProvider: TokenProvider,
        tokenRefresher: TokenRefreshHandling? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.tokenRefresher = tokenRefresher
        self.session = session
        self.decoder = .apiDecoder
        self.encoder = .apiEncoder
    }

    public func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await performRequest(endpoint, didRetryAfterRefresh: false)
        guard !data.isEmpty else {
            throw NetworkError.decodingFailed
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Log.error("Decoding failed: \(error)", category: .network)
            throw NetworkError.decodingFailed
        }
    }

    public func request(_ endpoint: APIEndpoint) async throws {
        _ = try await performRequest(endpoint, didRetryAfterRefresh: false)
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
        try validateResponse(response, data: responseData)
        return try decoder.decode(T.self, from: responseData)
    }

    // MARK: - Private

    private func performRequest(
        _ endpoint: APIEndpoint,
        didRetryAfterRefresh: Bool
    ) async throws -> Data {
        var request = try endpoint.asURLRequest(baseURL: baseURL, encoder: encoder)
        request = try await applyAuth(to: request, requiresAuth: endpoint.requiresAuth)

        Log.debug("\(endpoint.method.rawValue) \(endpoint.path)", category: .network)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401,
           endpoint.requiresAuth,
           !didRetryAfterRefresh,
           let tokenRefresher {
            try await tokenRefresher.refreshSession()
            return try await performRequest(endpoint, didRetryAfterRefresh: true)
        }

        try validateResponse(response, data: data)
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

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response type")
        }

        let statusCode = httpResponse.statusCode

        switch statusCode {
        case 200...299:
            return
        case 400:
            throw mapAPIError(statusCode: statusCode, data: data, fallback: .unknown("Bad request"))
        case 401:
            // Parse body: INVALID_OTP vs UNAUTHORIZED vs INVALID_TOKEN (not a blind unauthorized).
            throw mapAPIError(statusCode: statusCode, data: data, fallback: .unauthorized)
        case 403:
            throw mapAPIError(statusCode: statusCode, data: data, fallback: .forbidden)
        case 404:
            throw mapAPIError(statusCode: statusCode, data: data, fallback: .notFound)
        case 409:
            throw mapAPIError(statusCode: statusCode, data: data, fallback: .unknown("Conflict"))
        case 423:
            throw mapAPIError(statusCode: statusCode, data: data, fallback: .forbidden)
        case 429:
            throw mapAPIError(statusCode: statusCode, data: data, fallback: .rateLimited)
        case 503:
            throw mapAPIError(
                statusCode: statusCode,
                data: data,
                fallback: .serverError(statusCode: statusCode)
            )
        case 500...599:
            throw mapAPIError(
                statusCode: statusCode,
                data: data,
                fallback: .serverError(statusCode: statusCode)
            )
        default:
            throw mapAPIError(
                statusCode: statusCode,
                data: data,
                fallback: .unknown("HTTP \(statusCode)")
            )
        }
    }

    private func mapAPIError(
        statusCode: Int,
        data: Data,
        fallback: NetworkError
    ) -> Error {
        guard let body = try? decoder.decode(APIErrorBody.self, from: data) else {
            return fallback
        }

        switch body.error.uppercased() {
        case "INVALID_OTP":
            return AuthError.invalidOtp(
                body.message.isEmpty ? "Invalid or expired verification code." : body.message
            )
        case "INVALID_GOOGLE_TOKEN":
            return AuthError.invalidCredentials
        case "UNAUTHORIZED", "INVALID_TOKEN":
            return NetworkError.unauthorized
        case "ACCOUNT_LOCKED":
            return AuthError.accountLocked
        case "ACCOUNT_INACTIVE":
            return AuthError.accountInactive
        case "CANNOT_UNLINK_LAST_AUTH_METHOD":
            return AuthError.cannotUnlinkLastAuthMethod
        case "GOOGLE_ALREADY_LINKED":
            return AuthError.googleAlreadyLinked
        case "PROVIDER_ALREADY_LINKED":
            return AuthError.providerAlreadyLinked
        case "CONFLICT":
            return AuthError.emailAlreadyExists
        case "EMAIL_ALREADY_REGISTERED":
            return AuthError.emailAlreadyExists
        case "EMAIL_USE_GOOGLE":
            return AuthError.emailUseGoogle
        case "PHONE_ALREADY_REGISTERED":
            return AuthError.phoneAlreadyExists
        case "USERNAME_ALREADY_REGISTERED":
            return AuthError.usernameAlreadyExists
        case "OTP_RATE_LIMIT":
            return AuthError.otpRateLimited
        case "EMAIL_DELIVERY_FAILED":
            return NetworkError.unknown(
                body.message.isEmpty ? "Unable to send email. Please try again later." : body.message
            )
        case "VALIDATION_ERROR":
            return mapValidationError(body.message)
        case "NOT_FOUND":
            return NetworkError.notFound
        case "INTERNAL_ERROR":
            return NetworkError.serverError(statusCode: body.status)
        default:
            if body.message.isEmpty {
                return fallback
            }
            return NetworkError.unknown(body.message)
        }
    }

    private func mapValidationError(_ message: String) -> Error {
        if message.localizedCaseInsensitiveContains("otpcode") {
            return AuthError.invalidOtp(
                message.isEmpty ? "Enter the 6-digit code from your email." : message
            )
        }
        return NetworkError.unknown(message.isEmpty ? "Validation failed." : message)
    }

    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return .serverUnreachable
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
