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

    func testNavigationTargetOpensCommentFromMentionInComment() {
        let postId = UUID()
        let commentId = UUID()
        let notification = AppNotification(
            id: UUID(),
            type: .feedMentionedInComment,
            title: "Mentioned in comment",
            body: "Alice mentioned you",
            destination: NotificationDestination(screen: .postDetail, postId: postId, commentId: commentId)
        )

        XCTAssertEqual(notification.navigationTarget, .post(postId, commentId: commentId))
    }

    func testNavigationTargetOpensCommentFromPaymentEvidence() {
        let postId = UUID()
        let commentId = UUID()
        for type: NotificationType in [
            .paymentEvidenceSubmitted,
            .paymentEvidenceApproved,
            .paymentEvidenceRejected
        ] {
            let notification = AppNotification(
                id: UUID(),
                type: type,
                title: "Payment evidence",
                body: "Evidence updated",
                referenceId: postId,
                destination: NotificationDestination(screen: .postDetail, postId: postId, commentId: commentId)
            )
            XCTAssertEqual(notification.navigationTarget, .post(postId, commentId: commentId), "\(type)")
        }

        let legacyWithoutDestination = AppNotification(
            id: UUID(),
            type: .paymentEvidenceSubmitted,
            title: "Payment evidence",
            body: "Evidence submitted",
            referenceId: postId
        )
        XCTAssertEqual(legacyWithoutDestination.navigationTarget, .post(postId))
    }

    func testPushUserInfoOpensPostCommentFromPaymentEvidenceType() {
        let postId = UUID()
        let commentId = UUID()
        let destination = NotificationDestination.fromPushUserInfo([
            "type": "PAYMENT_EVIDENCE_REJECTED",
            "postId": postId.uuidString,
            "commentId": commentId.uuidString,
        ])

        XCTAssertEqual(destination?.screen, .postDetail)
        XCTAssertEqual(destination?.postId, postId)
        XCTAssertEqual(destination?.commentId, commentId)
    }

    func testNavigationTargetRoutesDebtReminderToExpenses() {
        let notification = AppNotification(
            id: UUID(),
            type: .dailyDebtReminder,
            title: "Unpaid amount",
            body: "You have an unpaid amount of 100 VND",
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

    func testPushUserInfoOpensConversationFromNestedDestination() {
        let conversationId = UUID()
        let destination = NotificationDestination.fromPushUserInfo([
            "destination": [
                "screen": "MESSAGES",
                "postId": conversationId.uuidString,
                "conversationId": conversationId.uuidString,
            ],
            "type": "DIRECT_MESSAGE",
        ])

        XCTAssertEqual(destination?.screen, .messages)
        XCTAssertEqual(destination?.conversationId, conversationId)
    }

    func testPushUserInfoOpensConversationFromTypeAndConversationId() {
        let conversationId = UUID()
        let destination = NotificationDestination.fromPushUserInfo([
            "type": "GROUP_MESSAGE",
            "conversationId": conversationId.uuidString,
        ])

        XCTAssertEqual(destination?.screen, .messages)
        XCTAssertEqual(destination?.conversationId, conversationId)
    }

    func testNavigationTargetOpensUserProfileFromFriendRequestSent() {
        let requesterId = UUID()
        let withProfileDestination = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Lời mời kết bạn mới",
            body: "Alice đã gửi lời mời kết bạn cho bạn",
            destination: NotificationDestination(screen: .userProfile, postId: requesterId),
            actorUserId: requesterId
        )
        XCTAssertEqual(withProfileDestination.navigationTarget, .userProfile(requesterId))

        let legacyFriendsDestination = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Lời mời kết bạn",
            body: "Alice đã gửi lời mời kết bạn cho bạn",
            destination: NotificationDestination(screen: .friends),
            actorUserId: requesterId
        )
        XCTAssertEqual(legacyFriendsDestination.navigationTarget, .userProfile(requesterId))
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
