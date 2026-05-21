import Foundation
import Networking

enum SocialEndpoint: APIEndpoint {
    case searchUsers(query: String, page: Int, size: Int)
    case generateMyQr
    case revokeMyQr

    var path: String {
        switch self {
        case .searchUsers:
            return "/v1/social/users/search"
        case .generateMyQr, .revokeMyQr:
            return "/v1/social/qr/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .searchUsers:
            return .get
        case .generateMyQr:
            return .post
        case .revokeMyQr:
            return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .searchUsers(let query, let page, let size):
            return [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        case .generateMyQr, .revokeMyQr:
            return nil
        }
    }

    var requiresAuth: Bool { true }
}
