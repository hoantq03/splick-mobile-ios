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
    case getGroup(groupId: UUID)
    case updateGroup(groupId: UUID, name: String, description: String?)
    case updateGroupAvatar(groupId: UUID, avatarURL: String)
    case deleteGroup(groupId: UUID)
    case joinGroupByCode(code: String)
    case joinGroupByQr(qrPayload: String)
    case listGroupMembers(groupId: UUID, status: String?, page: Int, size: Int)
    case getActiveGroupInviteCode(groupId: UUID)
    case generateGroupInviteCode(groupId: UUID)
    case revokeGroupInviteCode(groupId: UUID, invitationId: UUID)
    case generateGroupQr(groupId: UUID, ttlSeconds: Int?)
    case revokeGroupQr(groupId: UUID, qrId: UUID)
    case inviteFriendsToGroup(groupId: UUID, userIds: [UUID])
    case approveGroupMember(groupId: UUID, memberRowId: UUID)
    case rejectGroupMember(groupId: UUID, memberRowId: UUID)
    case removeGroupMember(groupId: UUID, memberRowId: UUID)
    case leaveGroup(groupId: UUID)
    case transferGroupOwnership(groupId: UUID, newOwnerId: UUID)
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
        case .joinGroupByCode:
            return "/v1/social/groups/join"
        case .joinGroupByQr:
            return "/v1/social/groups/join/qr"
        case .getGroup(let groupId), .updateGroup(let groupId, _, _), .deleteGroup(let groupId):
            return "/v1/social/groups/\(groupId.uuidString)"
        case .updateGroupAvatar(let groupId, _):
            return "/v1/social/groups/\(groupId.uuidString)/avatar"
        case .transferGroupOwnership(let groupId, _):
            return "/v1/social/groups/\(groupId.uuidString)/transfer-ownership"
        case .listGroupMembers(let groupId, _, _, _):
            return "/v1/social/groups/\(groupId.uuidString)/members"
        case .getActiveGroupInviteCode(let groupId):
            return "/v1/social/groups/\(groupId.uuidString)/invite-codes/active"
        case .generateGroupInviteCode(let groupId):
            return "/v1/social/groups/\(groupId.uuidString)/invite-codes"
        case .revokeGroupInviteCode(let groupId, let invitationId):
            return "/v1/social/groups/\(groupId.uuidString)/invite-codes/\(invitationId.uuidString)"
        case .generateGroupQr(let groupId, _):
            return "/v1/social/groups/\(groupId.uuidString)/qr"
        case .revokeGroupQr(let groupId, let qrId):
            return "/v1/social/groups/\(groupId.uuidString)/qr/\(qrId.uuidString)"
        case .inviteFriendsToGroup(let groupId, _):
            return "/v1/social/groups/\(groupId.uuidString)/members/invite"
        case .approveGroupMember(let groupId, let memberRowId):
            return "/v1/social/groups/\(groupId.uuidString)/members/\(memberRowId.uuidString)/approve"
        case .rejectGroupMember(let groupId, let memberRowId):
            return "/v1/social/groups/\(groupId.uuidString)/members/\(memberRowId.uuidString)/reject"
        case .removeGroupMember(let groupId, let memberRowId):
            return "/v1/social/groups/\(groupId.uuidString)/members/\(memberRowId.uuidString)"
        case .leaveGroup(let groupId):
            return "/v1/social/groups/\(groupId.uuidString)/membership"
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
             .listBlockedUsers, .listMyGroups, .listGroupMembers, .getActiveGroupInviteCode, .getGroup:
            return .get
        case .sendFriendRequest, .sendFriendRequestByQr, .generateMyQr, .acceptFriendRequest,
             .rejectFriendRequest, .createGroup, .generateGroupInviteCode, .inviteFriendsToGroup,
             .blockUser, .joinGroupByCode, .joinGroupByQr, .generateGroupQr, .approveGroupMember,
             .rejectGroupMember, .transferGroupOwnership:
            return .post
        case .revokeMyQr, .cancelFriendRequest, .removeFriend, .unblockUser, .deleteGroup,
             .revokeGroupInviteCode, .revokeGroupQr, .removeGroupMember, .leaveGroup:
            return .delete
        case .setFriendNickname, .updateGroup, .updateGroupAvatar:
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
        default:
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
        case .updateGroup(_, let name, let description):
            return UpdateGroupBodyDTO(name: name, description: description)
        case .updateGroupAvatar(_, let avatarURL):
            return UpdateAvatarBodyDTO(avatarUrl: avatarURL)
        case .joinGroupByCode(let code):
            return JoinGroupByCodeBodyDTO(code: code)
        case .joinGroupByQr(let qrPayload):
            return JoinGroupByQRBodyDTO(qrPayload: qrPayload)
        case .generateGroupQr(_, let ttlSeconds):
            return GenerateGroupQRBodyDTO(ttlSeconds: ttlSeconds)
        case .transferGroupOwnership(_, let newOwnerId):
            return TransferOwnershipBodyDTO(newOwnerId: newOwnerId)
        case .inviteFriendsToGroup(_, let userIds):
            return InviteFriendsBodyDTO(userIds: userIds)
        case .setFriendNickname(_, let nickname):
            return SetNicknameBodyDTO(nickname: nickname)
        case .blockUser(let userId):
            return BlockUserBodyDTO(userId: userId)
        default:
            return nil
        }
    }

    var requiresAuth: Bool { true }
}
