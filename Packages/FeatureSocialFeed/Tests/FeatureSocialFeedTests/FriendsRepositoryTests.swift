import XCTest
import FeatureFriends
import SplickDomain
@testable import FeatureSocialFeed

final class FriendsRepositoryTests: XCTestCase {

    private final class MockFriendsManagementRepository: FriendsManagementRepositoryProtocol, @unchecked Sendable {
        func searchUsers(query: String, page: Int, size: Int) async throws -> [UserSearchResult] {
            let u1 = UserSummary(id: UUID(), username: "alice", displayName: "Alice", avatarURL: nil)
            let u2 = UserSummary(id: UUID(), username: "bob", displayName: "Bob", avatarURL: nil)
            return [
                UserSearchResult(user: u1, friendStatus: .friends),
                UserSearchResult(user: u2, friendStatus: .requestSent)
            ]
        }

        func fetchMyFriends() async throws -> [UserSummary] { [] }
        func fetchMyFriendsPage(page: Int, size: Int) async throws -> FriendsPageResult {
            FriendsPageResult(friends: [], page: page, hasMore: false)
        }
        func loadCachedFriends(userId: UUID) async -> [UserSummary]? { nil }
        func saveCachedFriends(_ friends: [UserSummary], userId: UUID) async {}
        func invalidateCachedFriends(userId: UUID) async {}
        func fetchUserProfile(userId: UUID) async throws -> PublicUserProfile {
            let user = UserSummary(id: userId, username: "u", displayName: "U", avatarURL: nil)
            return PublicUserProfile(user: user, friendStatus: .none, stats: UserProfileStats(friendCount: 0, postCount: 0, groupCount: 0))
        }
        func fetchFriendPaymentProfile(userId: UUID) async throws -> PaymentProfile {
            PaymentProfile(userId: userId, qrImageURL: nil, accountName: "Acc", accountNumber: "123", bankName: "Bank", updatedAt: Date())
        }
        func discoveryPreference() async throws -> Bool { true }
        func updateDiscoveryPreference(nearbyEnabled: Bool) async throws -> Bool { true }
        func findNearbyUsers(lat: Double, lon: Double) async throws -> [UserSearchResult] { [] }
        func leaveNearbySession() async throws {}
        func searchUser(username: String) async throws -> UserSummary? { nil }
        func addFriend(username: String, message: String?) async throws -> UserSummary {
            UserSummary(id: UUID(), username: username, displayName: username, avatarURL: nil)
        }
        func fetchAllIncomingFriendRequests() async throws -> [IncomingFriendRequest] { [] }
        func fetchAllOutgoingFriendRequests() async throws -> [OutgoingFriendRequest] { [] }
        func fetchAllBlockedUsers() async throws -> [BlockedUser] { [] }
        func fetchIncomingFriendRequests(page: Int, size: Int) async throws -> [IncomingFriendRequest] { [] }
        func fetchOutgoingFriendRequests(page: Int, size: Int) async throws -> [OutgoingFriendRequest] { [] }
        func acceptFriendRequest(requestId: UUID) async throws {}
        func rejectFriendRequest(requestId: UUID) async throws {}
        func cancelFriendRequest(requestId: UUID) async throws {}
        func removeFriend(friendUserId: UUID) async throws {}
        func setFriendNickname(friendUserId: UUID, nickname: String?) async throws -> UserSummary {
            UserSummary(id: friendUserId, username: "nick", displayName: nickname ?? "nick", avatarURL: nil)
        }
        func fetchBlockedUsers(page: Int, size: Int) async throws -> [BlockedUser] { [] }
        func blockUser(userId: UUID) async throws {}
        func unblockUser(userId: UUID) async throws {}
        func addFriendFromQRCode(_ payload: String) async throws -> UserSummary {
            UserSummary(id: UUID(), username: "qr", displayName: "QR", avatarURL: nil)
        }
        func generateMyQr() async throws -> PersonalQRCode {
            PersonalQRCode(payload: "payload", version: 1, issuedAt: Date())
        }
        func revokeMyQr() async throws {}
    }

    func testFetchFriends() async throws {
        let mockMgmtRepo = MockFriendsManagementRepository()
        let repo = FriendsRepository(searchRepository: mockMgmtRepo)

        let friends = try await repo.fetchFriends(query: "al", page: 1, limit: 10)
        XCTAssertEqual(friends.count, 2)
        XCTAssertEqual(friends.first?.username, "alice")
    }
}
