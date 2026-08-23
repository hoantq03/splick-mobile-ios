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
        XCTAssertEqual(NotificationType(rawValue: "FRIEND_NICKNAME_CHANGED"), .friendNicknameChanged)
        XCTAssertEqual(
            NotificationType(rawValue: "BULK_SETTLEMENT_PENDING_APPROVAL"),
            .bulkSettlementPendingApproval
        )
        XCTAssertEqual(NotificationType(rawValue: "EXPENSE_SPLIT_BILL"), .expenseSplitBill)
        XCTAssertEqual(NotificationType(rawValue: "GROUP_INVITE"), .groupInvite)
    }

    func testNavigationTargetOpensConversationFromMessagesDestination() {
        let conversationId = UUID()
        let notification = AppNotification(
            id: UUID(),
            type: .directMessage,
            title: "Alice",
            body: "Hello",
            destination: NotificationDestination(screen: .messages, postId: conversationId)
        )

        XCTAssertEqual(notification.navigationTarget, .conversation(conversationId))
        XCTAssertEqual(
            NotificationDestination(screen: .messages, postId: conversationId).conversationId,
            conversationId
        )
    }

    func testNavigationTargetOpensUserProfileFromFriendAccepted() {
        let actorId = UUID()
        let notification = AppNotification(
            id: UUID(),
            type: .friendRequestAccepted,
            title: "Kết bạn thành công",
            body: "Alice",
            destination: NotificationDestination(screen: .userProfile, postId: actorId),
            actorUserId: actorId
        )

        XCTAssertEqual(notification.navigationTarget, .userProfile(actorId))
    }

    func testNavigationTargetOpensUserProfileFromFriendNicknameChanged() {
        let actorId = UUID()
        let notification = AppNotification(
            id: UUID(),
            type: .friendNicknameChanged,
            title: "Biệt danh",
            body: "Alice đã đặt biệt danh cho bạn: Minh",
            destination: NotificationDestination(screen: .userProfile, postId: actorId),
            actorUserId: actorId
        )

        XCTAssertEqual(notification.navigationTarget, .userProfile(actorId))
    }

    func testNavigationTargetRoutesBulkSettlementToExpenses() {
        let notification = AppNotification(
            id: UUID(),
            type: .bulkSettlementApproved,
            title: "Settlement approved",
            body: "Your settlement was approved"
        )

        XCTAssertEqual(notification.navigationTarget, .expenses)
    }
}
