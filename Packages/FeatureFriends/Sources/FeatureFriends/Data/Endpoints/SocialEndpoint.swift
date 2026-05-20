import Foundation
import Networking

enum SocialEndpoint: APIEndpoint {
    case searchUsers(query: String, page: Int, size: Int)

    var path: String {
        switch self {
        case .searchUsers:
            return "/v1/social/users/search"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .searchUsers:
            return .get
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
        }
    }

    var requiresAuth: Bool { true }
}
