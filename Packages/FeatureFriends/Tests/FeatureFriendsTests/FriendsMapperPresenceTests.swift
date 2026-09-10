import XCTest
@testable import FeatureFriends
import Common

final class FriendsMapperPresenceTests: XCTestCase {
    func test_presenceState_includesExplicitOffline() {
        let dto = FriendResponseDTO(
            friendId: UUID(),
            username: "peer",
            displayName: "Peer",
            avatarUrl: nil,
            nickname: nil,
            friendsSince: Date(),
            online: false,
            lastSeenAt: nil
        )

        let state = FriendsMapper.presenceState(from: dto)
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.isOnline, false)
        XCTAssertNil(state?.lastSeenAt)
    }

    func test_presenceState_skipsWhenPresenceFieldsMissing() {
        let dto = FriendResponseDTO(
            friendId: UUID(),
            username: "peer",
            displayName: "Peer",
            avatarUrl: nil,
            nickname: nil,
            friendsSince: Date(),
            online: nil,
            lastSeenAt: nil
        )

        XCTAssertNil(FriendsMapper.presenceState(from: dto))
    }
}
