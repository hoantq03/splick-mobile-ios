import XCTest
import Common

final class MessagingInboxMayHaveChangedTests: XCTestCase {
    func testNotificationNameMatchesSplickCoreBus() {
        XCTAssertEqual(
            Notification.Name.messagingInboxMayHaveChanged,
            MessagingInboxMayHaveChanged.notification
        )
        XCTAssertEqual(
            MessagingInboxMayHaveChanged.notification.rawValue,
            "splick.messagingInboxMayHaveChanged"
        )
    }

    func testPostDeliversToObserver() {
        let expectation = expectation(description: "messagingInboxMayHaveChanged")
        let token = NotificationCenter.default.addObserver(
            forName: MessagingInboxMayHaveChanged.notification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        MessagingInboxMayHaveChanged.post()
        wait(for: [expectation], timeout: 1)
    }
}
