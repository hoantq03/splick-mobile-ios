import Foundation
import Networking
import SplickDomain

public struct FriendsManagementRepository: FriendsManagementRepositoryProtocol {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchMyFriends() async throws -> [UserSummary] {
        let friends = try await SocialPageFetcher.fetchAll { page, size in
            let response: SocialPageFriendResponseDTO = try await apiClient.request(
                SocialEndpoint.listFriends(page: page, size: size)
            )
            return (response.content, response.page)
        }
        return friends.map(FriendsMapper.toUserSummary)
    }

    public func searchUsers(query: String, page: Int, size: Int) async throws -> [UserSearchResult] {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !normalized.isEmpty else { return [] }

        let response: SocialPageUserSearchResponseDTO = try await apiClient.request(
            SocialEndpoint.searchUsers(query: normalized, page: page, size: size)
        )
        return response.content.map(FriendsMapper.toUserSearchResult)
    }

    public func searchUser(username: String) async throws -> UserSummary? {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !normalized.isEmpty else { return nil }

        let results = try await searchUsers(query: normalized, page: 0, size: 20)
        return results.first {
            $0.user.username.caseInsensitiveCompare(normalized) == .orderedSame
        }?.user
    }

    public func addFriend(username: String, message: String?) async throws -> UserSummary {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !normalized.isEmpty else {
            throw FriendsError.invalidUsername
        }

        let trimmedMessage = message?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        let response: FriendRequestResponseDTO = try await apiClient.request(
            SocialEndpoint.sendFriendRequest(username: normalized, message: trimmedMessage)
        )
        return UserSummary(
            id: response.addresseeId,
            username: normalized,
            displayName: normalized,
            avatarURL: nil
        )
    }

    public func fetchIncomingFriendRequests(page: Int, size: Int) async throws -> [IncomingFriendRequest] {
        let response: SocialPageIncomingFriendRequestResponseDTO = try await apiClient.request(
            SocialEndpoint.listIncomingFriendRequests(page: page, size: size)
        )
        return response.content.map(FriendsMapper.toIncomingFriendRequest)
    }

    public func fetchAllIncomingFriendRequests() async throws -> [IncomingFriendRequest] {
        let items = try await SocialPageFetcher.fetchAll { page, size in
            let response: SocialPageIncomingFriendRequestResponseDTO = try await apiClient.request(
                SocialEndpoint.listIncomingFriendRequests(page: page, size: size)
            )
            return (response.content, response.page)
        }
        return items.map(FriendsMapper.toIncomingFriendRequest)
    }

    public func acceptFriendRequest(requestId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.acceptFriendRequest(requestId: requestId))
    }

    public func rejectFriendRequest(requestId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.rejectFriendRequest(requestId: requestId))
    }

    public func cancelFriendRequest(requestId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.cancelFriendRequest(requestId: requestId))
    }

    public func fetchOutgoingFriendRequests(page: Int, size: Int) async throws -> [OutgoingFriendRequest] {
        let response: SocialPageFriendRequestResponseDTO = try await apiClient.request(
            SocialEndpoint.listOutgoingFriendRequests(page: page, size: size)
        )
        return response.content.map(FriendsMapper.toOutgoingFriendRequest)
    }

    public func fetchAllOutgoingFriendRequests() async throws -> [OutgoingFriendRequest] {
        let items = try await SocialPageFetcher.fetchAll { page, size in
            let response: SocialPageFriendRequestResponseDTO = try await apiClient.request(
                SocialEndpoint.listOutgoingFriendRequests(page: page, size: size)
            )
            return (response.content, response.page)
        }
        return items.map(FriendsMapper.toOutgoingFriendRequest)
    }

    public func removeFriend(friendUserId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.removeFriend(friendUserId: friendUserId))
    }

    public func setFriendNickname(friendUserId: UUID, nickname: String?) async throws -> UserSummary {
        let response: FriendResponseDTO = try await apiClient.request(
            SocialEndpoint.setFriendNickname(friendUserId: friendUserId, nickname: nickname)
        )
        return FriendsMapper.toUserSummary(response)
    }

    public func fetchBlockedUsers(page: Int, size: Int) async throws -> [BlockedUser] {
        let response: SocialPageBlockedUserResponseDTO = try await apiClient.request(
            SocialEndpoint.listBlockedUsers(page: page, size: size)
        )
        return response.content.map(FriendsMapper.toBlockedUser)
    }

    public func fetchAllBlockedUsers() async throws -> [BlockedUser] {
        let items = try await SocialPageFetcher.fetchAll { page, size in
            let response: SocialPageBlockedUserResponseDTO = try await apiClient.request(
                SocialEndpoint.listBlockedUsers(page: page, size: size)
            )
            return (response.content, response.page)
        }
        return items.map(FriendsMapper.toBlockedUser)
    }

    public func blockUser(userId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.blockUser(userId: userId))
    }

    public func unblockUser(userId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.unblockUser(userId: userId))
    }

    public func addFriendFromQRCode(_ raw: String) async throws -> UserSummary {
        guard let action = SplickQRParser.parse(raw) else {
            throw FriendsError.invalidQRCode
        }

        switch action {
        case .addFriend(let username):
            return try await addFriend(username: username, message: nil)
        case .addFriendByServerPayload(let payload):
            let response: FriendRequestResponseDTO = try await apiClient.request(
                SocialEndpoint.sendFriendRequestByQr(qrPayload: payload, message: nil)
            )
            let username = response.addresseeUsername ?? "user"
            let displayName = response.addresseeDisplayName ?? username
            return UserSummary(
                id: response.addresseeId,
                username: username,
                displayName: displayName,
                avatarURL: nil
            )
        case .joinGroup:
            throw FriendsError.invalidQRCode
        }
    }

    public func generateMyQr() async throws -> PersonalQRCode {
        let response: MyQRResponseDTO = try await apiClient.request(SocialEndpoint.generateMyQr)
        return PersonalQRCode(
            payload: response.payload,
            version: response.version,
            issuedAt: response.issuedAt
        )
    }

    public func revokeMyQr() async throws {
        try await apiClient.request(SocialEndpoint.revokeMyQr)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

public enum FriendsError: LocalizedError {
    case notImplemented
    case invalidUsername
    case userNotFound
    case alreadyFriends
    case invalidQRCode
    case groupNotFound
    case alreadyInGroup
    case invalidGroupName
    case invalidInviteSelection

    public var errorDescription: String? {
        switch self {
        case .notImplemented: return "This feature is not available yet."
        case .invalidGroupName: return "Enter a group name."
        case .invalidInviteSelection: return "Chọn ít nhất một bạn bè."
        case .invalidUsername: return "Enter a valid username."
        case .userNotFound: return "User not found."
        case .alreadyFriends: return "You are already friends."
        case .invalidQRCode: return "Invalid QR code."
        case .groupNotFound: return "Group not found."
        case .alreadyInGroup: return "You are already in this group."
        }
    }
}
