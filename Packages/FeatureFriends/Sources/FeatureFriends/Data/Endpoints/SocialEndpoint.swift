import Foundation
import Networking

enum SocialEndpoint: APIEndpoint {
    case searchUsers(query: String, page: Int, size: Int)
    case sendFriendRequest(username: String, message: String?)
    case sendFriendRequestByQr(qrPayload: String, message: String?)
    case listFriends(page: Int, size: Int)
    case listIncomingFriendRequests(page: Int, size: Int)
    case listOutgoingFriendRequests(page: Int, size: Int)
    case acceptFriendRequest(requestId: UUID)
    case rejectFriendRequest(requestId: UUID)
    case cancelFriendRequest(requestId: UUID)
    case removeFriend(friendUserId: UUID)
    case setFriendNickname(friendUserId: UUID, nickname: String?)
    case listBlockedUsers(page: Int, size: Int)
    case blockUser(userId: UUID)
    case unblockUser(userId: UUID)
    case listMyGroups(page: Int, size: Int)
    case createGroup(name: String, description: String?)
    case listGroupMembers(groupId: UUID, status: String?, page: Int, size: Int)
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
        case .listGroupMembers(let groupId, _, _, _):
            return "/v1/social/groups/\(groupId.uuidString)/members"
        case .getActiveGroupInviteCode(let groupId):
            return "/v1/social/groups/\(groupId.uuidString)/invite-codes/active"
        case .generateGroupInviteCode(let groupId):
            return "/v1/social/groups/\(groupId.uuidString)/invite-codes"
        case .inviteFriendsToGroup(let groupId, _):
            return "/v1/social/groups/\(groupId.uuidString)/members/invite"
        case .sendFriendRequest:
            return "/v1/social/friendships/requests"
        case .sendFriendRequestByQr:
            return "/v1/social/friendships/requests/qr"
        case .listIncomingFriendRequests:
            return "/v1/social/friendships/requests/incoming"
        case .listOutgoingFriendRequests:
            return "/v1/social/friendships/requests/outgoing"
        case .removeFriend(let friendUserId):
            return "/v1/social/friendships/\(friendUserId.uuidString)"
        case .setFriendNickname(let friendUserId, _):
            return "/v1/social/friendships/\(friendUserId.uuidString)/nickname"
        case .listBlockedUsers, .blockUser:
            return "/v1/social/blocks"
        case .unblockUser(let userId):
            return "/v1/social/blocks/\(userId.uuidString)"
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
        case .searchUsers, .listFriends, .listIncomingFriendRequests, .listOutgoingFriendRequests,
             .listBlockedUsers, .listMyGroups, .listGroupMembers, .getActiveGroupInviteCode:
            return .get
        case .sendFriendRequest, .sendFriendRequestByQr, .generateMyQr, .acceptFriendRequest,
             .rejectFriendRequest, .createGroup, .generateGroupInviteCode, .inviteFriendsToGroup,
             .blockUser:
            return .post
        case .revokeMyQr, .cancelFriendRequest, .removeFriend, .unblockUser:
            return .delete
        case .setFriendNickname:
            return .patch
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
             .listOutgoingFriendRequests(let page, let size),
             .listBlockedUsers(let page, let size),
             .listMyGroups(let page, let size):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        case .listGroupMembers(_, let status, let page, let size):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
            if let status, !status.isEmpty {
                items.append(URLQueryItem(name: "status", value: status))
            }
            return items
        case .sendFriendRequest, .sendFriendRequestByQr, .generateMyQr, .revokeMyQr,
             .getActiveGroupInviteCode, .acceptFriendRequest, .rejectFriendRequest,
             .cancelFriendRequest, .createGroup, .generateGroupInviteCode, .inviteFriendsToGroup,
             .removeFriend, .setFriendNickname, .blockUser, .unblockUser:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .sendFriendRequest(let username, let message):
            return SendFriendRequestBodyDTO(username: username, message: message)
        case .sendFriendRequestByQr(let qrPayload, let message):
            return SendFriendRequestByQrBodyDTO(qrPayload: qrPayload, message: message)
        case .createGroup(let name, let description):
            return CreateGroupBodyDTO(name: name, description: description)
        case .inviteFriendsToGroup(_, let userIds):
            return InviteFriendsBodyDTO(userIds: userIds)
        case .setFriendNickname(_, let nickname):
            return SetNicknameBodyDTO(nickname: nickname)
        case .blockUser(let userId):
            return BlockUserBodyDTO(userId: userId)
        case .searchUsers, .listFriends, .listIncomingFriendRequests, .listOutgoingFriendRequests,
             .listBlockedUsers, .listMyGroups, .listGroupMembers,
             .generateMyQr, .revokeMyQr, .getActiveGroupInviteCode, .generateGroupInviteCode,
             .acceptFriendRequest, .rejectFriendRequest, .cancelFriendRequest, .removeFriend, .unblockUser:
            return nil
        }
    }

    var requiresAuth: Bool { true }
}
