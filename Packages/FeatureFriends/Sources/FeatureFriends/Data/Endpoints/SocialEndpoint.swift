import Foundation
import Networking

enum SocialEndpoint: APIEndpoint {
    case searchUsers(query: String, page: Int, size: Int)
    case sendFriendRequest(username: String, message: String?)
    case listFriends(page: Int, size: Int)
    case listIncomingFriendRequests(page: Int, size: Int)
    case acceptFriendRequest(requestId: UUID)
    case rejectFriendRequest(requestId: UUID)
    case cancelFriendRequest(requestId: UUID)
    case listMyGroups(page: Int, size: Int)
    case createGroup(name: String, description: String?)
    case getActiveGroupInviteCode(groupId: UUID)
    case generateGroupInviteCode(groupId: UUID)
    case inviteFriendsToGroup(groupId: UUID, userIds: [UUID])
    case generateMyQr
    case revokeMyQr

    var path: String {
        switch self {
        case .searchUsers:
            return "/v1/social/users/search"
        case .listFriends:
            return "/v1/social/friendships"
        case .listMyGroups, .createGroup:
            return "/v1/social/groups"
        case .getActiveGroupInviteCode(let groupId):
            return "/v1/social/groups/\(groupId.uuidString)/invite-codes/active"
        case .generateGroupInviteCode(let groupId):
            return "/v1/social/groups/\(groupId.uuidString)/invite-codes"
        case .inviteFriendsToGroup(let groupId, _):
            return "/v1/social/groups/\(groupId.uuidString)/members/invite"
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
        case .searchUsers, .listFriends, .listIncomingFriendRequests, .listMyGroups:
            return .get
        case .getActiveGroupInviteCode:
            return .get
        case .sendFriendRequest, .generateMyQr, .acceptFriendRequest, .rejectFriendRequest,
             .createGroup, .generateGroupInviteCode, .inviteFriendsToGroup:
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
        case .listFriends(let page, let size),
             .listIncomingFriendRequests(let page, let size),
             .listMyGroups(let page, let size):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        case .sendFriendRequest, .generateMyQr, .revokeMyQr, .getActiveGroupInviteCode,
             .acceptFriendRequest, .rejectFriendRequest, .cancelFriendRequest, .createGroup,
             .generateGroupInviteCode, .inviteFriendsToGroup:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .sendFriendRequest(let username, let message):
            return SendFriendRequestBodyDTO(username: username, message: message)
        case .createGroup(let name, let description):
            return CreateGroupBodyDTO(name: name, description: description)
        case .inviteFriendsToGroup(_, let userIds):
            return InviteFriendsBodyDTO(userIds: userIds)
        case .searchUsers, .listFriends, .listIncomingFriendRequests, .listMyGroups,
             .generateMyQr, .revokeMyQr, .getActiveGroupInviteCode, .generateGroupInviteCode,
             .acceptFriendRequest, .rejectFriendRequest, .cancelFriendRequest:
            return nil
        }
    }

    var requiresAuth: Bool { true }
}
