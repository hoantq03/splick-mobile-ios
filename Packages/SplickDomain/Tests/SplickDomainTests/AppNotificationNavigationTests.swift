import XCTest
@testable import SplickDomain

final class AppNotificationNavigationTests: XCTestCase {

    func testNavigationTargetOpensPostFromDestination() {
        let postId = UUID()
        let notification = AppNotification(
            id: UUID(),
            type: .postCommented,
            title: "New comment",
            body: "Alice commented",
            destination: NotificationDestination(screen: .postDetail, postId: postId)
        )

        XCTAssertEqual(notification.navigationTarget, .post(postId))
    }

    func testNavigationTargetRoutesDebtReminderToExpenses() {
        let notification = AppNotification(
            id: UUID(),
            type: .dailyDebtReminder,
            title: "Outstanding debts",
            body: "You owe 100 VND",
            destination: NotificationDestination(screen: .expenses, postId: nil)
        )

        XCTAssertEqual(notification.navigationTarget, .expenses)
    }

    func testNavigationTargetRoutesStreakReminderToFeed() {
        let notification = AppNotification(
            id: UUID(),
            type: .streakReminderEvening,
            title: "Keep your streak",
            body: "Post today",
            destination: NotificationDestination(screen: .feed, postId: nil)
        )

        XCTAssertEqual(notification.navigationTarget, .feed)
    }

    func testNotificationTypeMapsBackendMentionTypes() {
        XCTAssertEqual(NotificationType(rawValue: "FEED_MENTIONED_IN_POST"), .feedMentionedInPost)
        XCTAssertEqual(NotificationType(rawValue: "FEED_MENTIONED_IN_COMMENT"), .feedMentionedInComment)
        XCTAssertEqual(NotificationType(rawValue: "FRIEND_REQUEST_ACCEPTED"), .friendRequestAccepted)
    }
}
