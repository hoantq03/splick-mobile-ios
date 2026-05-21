import Foundation
import Networking
import SplickDomain

public struct FriendsManagementRepository: FriendsManagementRepositoryProtocol {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchMyFriends() async throws -> [UserSummary] { [] }

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

    public func addFriend(username: String) async throws -> UserSummary {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !normalized.isEmpty else {
            throw FriendsError.invalidUsername
        }

        let response: FriendRequestResponseDTO = try await apiClient.request(
            SocialEndpoint.sendFriendRequest(username: normalized, message: nil)
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

    public func acceptFriendRequest(requestId: UUID) async throws {
        let _: FriendshipResponseDTO = try await apiClient.request(
            SocialEndpoint.acceptFriendRequest(requestId: requestId)
        )
    }

    public func rejectFriendRequest(requestId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.rejectFriendRequest(requestId: requestId))
    }

    public func cancelFriendRequest(requestId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.cancelFriendRequest(requestId: requestId))
    }

    public func addFriendFromQRCode(_ payload: String) async throws -> UserSummary {
        throw FriendsError.notImplemented
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

public enum FriendsError: LocalizedError {
    case notImplemented
    case invalidUsername
    case userNotFound
    case alreadyFriends
    case invalidQRCode
    case groupNotFound
    case alreadyInGroup

    public var errorDescription: String? {
        switch self {
        case .notImplemented: return "This feature is not available yet."
        case .invalidUsername: return "Enter a valid username."
        case .userNotFound: return "User not found."
        case .alreadyFriends: return "You are already friends."
        case .invalidQRCode: return "Invalid QR code."
        case .groupNotFound: return "Group not found."
        case .alreadyInGroup: return "You are already in this group."
        }
    }
}
