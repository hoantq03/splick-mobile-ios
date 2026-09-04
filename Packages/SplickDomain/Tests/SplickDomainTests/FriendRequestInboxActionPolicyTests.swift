import XCTest
@testable import SplickDomain

final class FriendRequestInboxActionPolicyTests: XCTestCase {

    func testShowsActionsWhenRequestStillPending() {
        let requestId = UUID()
        let notification = friendRequest(referenceId: requestId)

        XCTAssertTrue(
            FriendRequestInboxActionPolicy.shouldShowRespondActions(
                for: notification,
                hasStoredOutcome: false,
                pendingIncoming: PendingIncomingFriendRequests(
                    requestIds: [requestId],
                    requesterIds: [UUID()]
                )
            )
        )
    }

    func testHidesActionsWhenRequestNoLongerPending() {
        let notification = friendRequest(referenceId: UUID())

        XCTAssertFalse(
            FriendRequestInboxActionPolicy.shouldShowRespondActions(
                for: notification,
                hasStoredOutcome: false,
                pendingIncoming: PendingIncomingFriendRequests(
                    requestIds: [UUID()],
                    requesterIds: []
                )
            )
        )
    }

    func testHidesActionsWhenAlreadyRespondedLocally() {
        let requestId = UUID()
        let notification = friendRequest(referenceId: requestId)

        XCTAssertFalse(
            FriendRequestInboxActionPolicy.shouldShowRespondActions(
                for: notification,
                hasStoredOutcome: true,
                pendingIncoming: PendingIncomingFriendRequests(
                    requestIds: [requestId],
                    requesterIds: []
                )
            )
        )
    }

    func testHidesActionsWhenIncomingInboxIsEmpty() {
        let notification = friendRequest(referenceId: UUID())

        XCTAssertFalse(
            FriendRequestInboxActionPolicy.shouldShowRespondActions(
                for: notification,
                hasStoredOutcome: false,
                pendingIncoming: PendingIncomingFriendRequests(
                    requestIds: [],
                    requesterIds: []
                )
            )
        )
    }

    func testHidesStaleRequestAfterFailedAccept() {
        let requestId = UUID()
        let notification = friendRequest(referenceId: requestId)

        XCTAssertFalse(
            FriendRequestInboxActionPolicy.shouldShowRespondActions(
                for: notification,
                hasStoredOutcome: false,
                pendingIncoming: nil,
                staleRequestIds: [requestId]
            )
        )
    }

    private func friendRequest(referenceId: UUID) -> AppNotification {
        AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Friend request",
            body: "Alice sent you a friend request",
            referenceId: referenceId,
            actorUserId: UUID()
        )
    }
}
