import Foundation
import SplickDomain

public struct FriendsManagementRepository: FriendsManagementRepositoryProtocol {
    public init() {}

    public func fetchMyFriends() async throws -> [UserSummary] { [] }

    public func searchUser(username: String) async throws -> UserSummary? { nil }

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
