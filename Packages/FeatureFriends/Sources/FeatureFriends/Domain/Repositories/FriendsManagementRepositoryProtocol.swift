import Foundation
import SplickDomain

public protocol FriendsManagementRepositoryProtocol: Sendable {
    func fetchMyFriends() async throws -> [UserSummary]
    func searchUsers(query: String, page: Int, size: Int) async throws -> [UserSearchResult]
    func searchUser(username: String) async throws -> UserSummary?
    func addFriend(username: String) async throws -> UserSummary
    func fetchIncomingFriendRequests(page: Int, size: Int) async throws -> [IncomingFriendRequest]
    func acceptFriendRequest(requestId: UUID) async throws
    func rejectFriendRequest(requestId: UUID) async throws
    func cancelFriendRequest(requestId: UUID) async throws
    func addFriendFromQRCode(_ payload: String) async throws -> UserSummary
    func generateMyQr() async throws -> PersonalQRCode
    func revokeMyQr() async throws
}
