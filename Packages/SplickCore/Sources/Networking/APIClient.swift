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
    private let localeProvider: LocaleHeaderProviding?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        baseURL: String = AppConstants.API.baseURL,
        tokenProvider: TokenProvider,
        tokenRefresher: TokenRefreshHandling? = nil,
        localeProvider: LocaleHeaderProviding? = nil,
        session: URLSession = .splick
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.tokenRefresher = tokenRefresher
        self.localeProvider = localeProvider
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
        request = try await applyLocale(to: request)
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

        let start = Date()
        let (responseData, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            let traceId = httpResponse.value(forHTTPHeaderField: APIRequestCorrelation.headerName) ?? "-"
            Log.debug(
                "UPLOAD \(endpoint.path) → \(httpResponse.statusCode) (\(durationMs)ms)",
                category: .network,
                metadata: ["traceId": traceId]
            )
        }
        try validateResponse(response, data: responseData)
        return try decoder.decode(T.self, from: responseData)
    }

    // MARK: - Private

    private func performRequest(
        _ endpoint: APIEndpoint,
        didRetryAfterRefresh: Bool
    ) async throws -> Data {
        var request = try endpoint.asURLRequest(baseURL: baseURL, encoder: encoder)
        request = try await applyLocale(to: request)
        request = try await applyAuth(to: request, requiresAuth: endpoint.requiresAuth)

        Log.debug("\(endpoint.method.rawValue) \(endpoint.path)", category: .network)

        let start = Date()
        let (data, response): (Data, URLResponse)
        do {
            try Task.checkCancellation()
            (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            throw mapURLError(error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            let traceId = httpResponse.value(forHTTPHeaderField: APIRequestCorrelation.headerName) ?? "-"
            Log.debug(
                "\(endpoint.method.rawValue) \(endpoint.path) → \(httpResponse.statusCode) (\(durationMs)ms)",
                category: .network,
                metadata: ["traceId": traceId]
            )
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

    private func applyLocale(to request: URLRequest) async throws -> URLRequest {
        guard let localeProvider else { return request }
        var localizedRequest = request
        localizedRequest.setValue(
            await localeProvider.acceptLanguageHeader(),
            forHTTPHeaderField: "Accept-Language"
        )
        return localizedRequest
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
        default:
            let traceId = resolveTraceId(from: httpResponse, data: data)
            logApiFailure(statusCode: statusCode, traceId: traceId)
            switch statusCode {
            case 400:
                throw mapAPIError(statusCode: statusCode, data: data, traceId: traceId, fallback: .unknown("Bad request"))
            case 401:
                throw mapAPIError(statusCode: statusCode, data: data, traceId: traceId, fallback: .unauthorized)
            case 403:
                throw mapAPIError(statusCode: statusCode, data: data, traceId: traceId, fallback: .forbidden)
            case 404:
                throw mapAPIError(statusCode: statusCode, data: data, traceId: traceId, fallback: .notFound)
            case 409:
                throw mapAPIError(statusCode: statusCode, data: data, traceId: traceId, fallback: .unknown("Conflict"))
            case 423:
                throw mapAPIError(statusCode: statusCode, data: data, traceId: traceId, fallback: .forbidden)
            case 429:
                throw mapAPIError(statusCode: statusCode, data: data, traceId: traceId, fallback: .rateLimited)
            case 503:
                throw mapAPIError(
                    statusCode: statusCode,
                    data: data,
                    traceId: traceId,
                    fallback: .serverError(statusCode: statusCode, traceId: traceId)
                )
            case 500...599:
                throw mapAPIError(
                    statusCode: statusCode,
                    data: data,
                    traceId: traceId,
                    fallback: .serverError(statusCode: statusCode, traceId: traceId)
                )
            default:
                throw mapAPIError(
                    statusCode: statusCode,
                    data: data,
                    traceId: traceId,
                    fallback: .unknown("HTTP \(statusCode)")
                )
            }
        }
    }

    private func resolveTraceId(from response: HTTPURLResponse, data: Data) -> String? {
        if let headerValue = response.value(forHTTPHeaderField: APIRequestCorrelation.headerName),
           !headerValue.isEmpty {
            return headerValue
        }
        if let body = try? decoder.decode(APIErrorBody.self, from: data),
           let traceId = body.traceId,
           !traceId.isEmpty {
            return traceId
        }
        return nil
    }

    private func logApiFailure(statusCode: Int, traceId: String?) {
        var metadata: [String: String] = ["status": String(statusCode)]
        if let traceId, !traceId.isEmpty {
            metadata["traceId"] = traceId
        }
        Log.error("API request failed", category: .network, metadata: metadata)
    }

    private func mapAPIError(
        statusCode: Int,
        data: Data,
        traceId: String?,
        fallback: NetworkError
    ) -> Error {
        guard let body = try? decoder.decode(APIErrorBody.self, from: data) else {
            return applyTraceId(to: fallback, traceId: traceId)
        }

        let resolvedTraceId = body.traceId ?? traceId

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
            return NetworkError.serverError(statusCode: body.status, traceId: resolvedTraceId)
        default:
            if body.message.isEmpty {
                return applyTraceId(to: fallback, traceId: resolvedTraceId)
            }
            return NetworkError.unknown(body.message, traceId: resolvedTraceId)
        }
    }

    private func applyTraceId(to error: NetworkError, traceId: String?) -> NetworkError {
        guard let traceId, !traceId.isEmpty else { return error }
        switch error {
        case .serverError(let statusCode, _):
            return .serverError(statusCode: statusCode, traceId: traceId)
        case .unknown(let message, _):
            return .unknown(message, traceId: traceId)
        default:
            return error
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

    private func mapURLError(_ error: URLError) -> Error {
        switch error.code {
        case .cancelled:
            return CancellationError()
        case .notConnectedToInternet, .networkConnectionLost:
            return NetworkError.noConnection
        case .timedOut:
            return NetworkError.timeout
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return NetworkError.serverUnreachable
        default:
            return NetworkError.unknown(error.localizedDescription)
        }
    }
}
