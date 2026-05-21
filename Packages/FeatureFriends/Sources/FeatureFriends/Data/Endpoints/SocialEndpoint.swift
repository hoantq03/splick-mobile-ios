import Foundation
import Networking

enum SocialEndpoint: APIEndpoint {
    case searchUsers(query: String, page: Int, size: Int)
    case sendFriendRequest(username: String, message: String?)
    case listIncomingFriendRequests(page: Int, size: Int)
    case acceptFriendRequest(requestId: UUID)
    case rejectFriendRequest(requestId: UUID)
    case cancelFriendRequest(requestId: UUID)
    case generateMyQr
    case revokeMyQr

    var path: String {
        switch self {
        case .searchUsers:
            return "/v1/social/users/search"
        case .sendFriendRequest:
            return "/v1/social/friendships/requests"
        case .listIncomingFriendRequests:
            return "/v1/social/friendships/requests/incoming"
        case .acceptFriendRequest(let requestId):
            return "/v1/social/friendships/requests/\(requestId.uuidString)/accept"
        case .rejectFriendRequest(let requestId):
            return "/v1/social/friendships/requests/\(requestId.uuidString)/reject"
        case .cancelFriendRequest(let requestId):
            return "/v1/social/friendships/requests/\(requestId.uuidString)"
        case .generateMyQr, .revokeMyQr:
            return "/v1/social/qr/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .searchUsers, .listIncomingFriendRequests:
            return .get
        case .sendFriendRequest, .generateMyQr, .acceptFriendRequest, .rejectFriendRequest:
            return .post
        case .revokeMyQr, .cancelFriendRequest:
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
        case .listIncomingFriendRequests(let page, let size):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        case .sendFriendRequest, .generateMyQr, .revokeMyQr,
             .acceptFriendRequest, .rejectFriendRequest, .cancelFriendRequest:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .sendFriendRequest(let username, let message):
            return SendFriendRequestBodyDTO(username: username, message: message)
        case .searchUsers, .listIncomingFriendRequests, .generateMyQr, .revokeMyQr,
             .acceptFriendRequest, .rejectFriendRequest, .cancelFriendRequest:
            return nil
        }
    }

    var requiresAuth: Bool { true }
}
