import Foundation
import Common

public protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Encodable? { get }
    var requiresAuth: Bool { get }
}

extension APIEndpoint {
    public var headers: [String: String]? { nil }
    public var queryItems: [URLQueryItem]? { nil }
    public var body: Encodable? { nil }
    public var requiresAuth: Bool { true }

    public func asURLRequest(baseURL: String, encoder: JSONEncoder = .apiEncoder) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = AppConstants.API.timeoutInterval

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        _encode = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
