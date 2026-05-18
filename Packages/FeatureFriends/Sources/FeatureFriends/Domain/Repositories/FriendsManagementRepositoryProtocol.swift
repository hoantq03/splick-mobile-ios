import Foundation
import SplickDomain

public protocol FriendsManagementRepositoryProtocol: Sendable {
    func fetchMyFriends() async throws -> [UserSummary]
    func searchUser(username: String) async throws -> UserSummary?
    func addFriend(username: String) async throws -> UserSummary
    func addFriendFromQRCode(_ payload: String) async throws -> UserSummary
}
