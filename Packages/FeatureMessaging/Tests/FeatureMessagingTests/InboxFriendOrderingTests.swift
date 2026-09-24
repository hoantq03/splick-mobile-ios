import XCTest
import Common
import SplickDomain
@testable import FeatureMessaging

final class InboxFriendOrderingTests: XCTestCase {
    func test_sorted_putsOnlineFriendsBeforeRecentlySeen() {
        let online = friend(name: "Lan")
        let recent = friend(name: "Minh")
        let older = friend(name: "An")
        let now = Date()
        let presence: [UUID: UserPresenceState] = [
            online.id: UserPresenceState(userId: online.id, isOnline: true, lastSeenAt: now.addingTimeInterval(-3_600)),
            recent.id: UserPresenceState(userId: recent.id, isOnline: false, lastSeenAt: now.addingTimeInterval(-60)),
            older.id: UserPresenceState(userId: older.id, isOnline: false, lastSeenAt: now.addingTimeInterval(-7_200))
        ]

        let ordered = InboxFriendOrdering.sorted([older, recent, online], presence: presence)

        XCTAssertEqual(ordered.map(\.id), [online.id, recent.id, older.id])
    }

    func test_sorted_ordersOfflineFriendsByMostRecentLastSeen() {
        let later = friend(name: "Binh")
        let earlier = friend(name: "Chi")
        let now = Date()
        let presence: [UUID: UserPresenceState] = [
            later.id: UserPresenceState(userId: later.id, isOnline: false, lastSeenAt: now),
            earlier.id: UserPresenceState(userId: earlier.id, isOnline: false, lastSeenAt: now.addingTimeInterval(-120))
        ]

        let ordered = InboxFriendOrdering.sorted([earlier, later], presence: presence)

        XCTAssertEqual(ordered.map(\.id), [later.id, earlier.id])
    }

    private func friend(name: String) -> UserSummary {
        UserSummary(id: UUID(), username: name.lowercased(), displayName: name)
    }
}
