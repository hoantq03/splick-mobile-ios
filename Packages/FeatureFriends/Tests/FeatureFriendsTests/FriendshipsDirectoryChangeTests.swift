import XCTest
import Common
@testable import FeatureFriends

final class FriendshipsDirectoryChangeTests: XCTestCase {
    func testNotificationNameMatchesSplickCoreBus() {
        XCTAssertEqual(
            Notification.Name.friendshipsDirectoryDidChange,
            FriendshipsDirectoryChange.notification
        )
        XCTAssertEqual(
            FriendshipsDirectoryChange.notification.rawValue,
            "splick.friendshipsDirectoryDidChange"
        )
    }

    func testPostDeliversToObserver() {
        let expectation = expectation(description: "friendshipsDirectoryDidChange")
        let token = NotificationCenter.default.addObserver(
            forName: FriendshipsDirectoryChange.notification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        FriendshipsDirectoryChange.post()
        wait(for: [expectation], timeout: 1)
    }
}
