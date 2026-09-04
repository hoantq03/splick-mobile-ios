import Foundation
import SplickDomain

public protocol FriendsManagementRepositoryProtocol: Sendable {
    func fetchMyFriends() async throws -> [UserSummary]
    func fetchMyFriendsPage(page: Int, size: Int) async throws -> FriendsPageResult
    func loadCachedFriends(userId: UUID) async -> [UserSummary]?
    func saveCachedFriends(_ friends: [UserSummary], userId: UUID) async
    func invalidateCachedFriends(userId: UUID) async
    func fetchUserProfile(userId: UUID) async throws -> PublicUserProfile
    func fetchFriendPaymentProfile(userId: UUID) async throws -> PaymentProfile
    func searchUsers(query: String, page: Int, size: Int) async throws -> [UserSearchResult]
    func discoveryPreference() async throws -> Bool
    func updateDiscoveryPreference(nearbyEnabled: Bool) async throws -> Bool
    func findNearbyUsers(lat: Double, lon: Double) async throws -> [UserSearchResult]
    func leaveNearbySession() async throws
    func searchUser(username: String) async throws -> UserSummary?
    func addFriend(username: String, message: String?) async throws -> UserSummary
    func fetchAllIncomingFriendRequests() async throws -> [IncomingFriendRequest]
    func fetchAllOutgoingFriendRequests() async throws -> [OutgoingFriendRequest]
    func fetchAllBlockedUsers() async throws -> [BlockedUser]
    func fetchIncomingFriendRequests(page: Int, size: Int) async throws -> [IncomingFriendRequest]
    func fetchOutgoingFriendRequests(page: Int, size: Int) async throws -> [OutgoingFriendRequest]
    func acceptFriendRequest(requestId: UUID) async throws
    func rejectFriendRequest(requestId: UUID) async throws
    func cancelFriendRequest(requestId: UUID) async throws
    func removeFriend(friendUserId: UUID) async throws
    func setFriendNickname(friendUserId: UUID, nickname: String?) async throws -> UserSummary
    func fetchBlockedUsers(page: Int, size: Int) async throws -> [BlockedUser]
    func blockUser(userId: UUID) async throws
    func unblockUser(userId: UUID) async throws
    func addFriendFromQRCode(_ payload: String) async throws -> UserSummary
    func generateMyQr() async throws -> PersonalQRCode
    func revokeMyQr() async throws
}
