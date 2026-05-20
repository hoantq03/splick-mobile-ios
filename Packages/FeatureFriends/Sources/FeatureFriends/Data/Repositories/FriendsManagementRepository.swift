import Foundation
import Networking
import SplickDomain

public struct FriendsManagementRepository: FriendsManagementRepositoryProtocol {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchMyFriends() async throws -> [UserSummary] { [] }

    public func searchUser(username: String) async throws -> UserSummary? {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !normalized.isEmpty else { return nil }

        let response: SocialPageUserSearchResponseDTO = try await apiClient.request(
            SocialEndpoint.searchUsers(query: normalized, page: 0, size: 20)
        )

        return response.content
            .first { $0.username.caseInsensitiveCompare(normalized) == .orderedSame }
            .map(FriendsMapper.toUserSummary)
    }

    public func addFriend(username: String) async throws -> UserSummary {
        throw FriendsError.notImplemented
    }

    public func addFriendFromQRCode(_ payload: String) async throws -> UserSummary {
        throw FriendsError.notImplemented
    }
}

public enum FriendsError: LocalizedError {
    case notImplemented
    case userNotFound
    case alreadyFriends
    case invalidQRCode
    case groupNotFound
    case alreadyInGroup

    public var errorDescription: String? {
        switch self {
        case .notImplemented: return "This feature is not available yet."
        case .userNotFound: return "User not found."
        case .alreadyFriends: return "You are already friends."
        case .invalidQRCode: return "Invalid QR code."
        case .groupNotFound: return "Group not found."
        case .alreadyInGroup: return "You are already in this group."
        }
    }
}
