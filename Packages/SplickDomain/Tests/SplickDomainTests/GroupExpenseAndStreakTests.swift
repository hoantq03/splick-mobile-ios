import XCTest
@testable import SplickDomain

final class GroupExpenseAndStreakTests: XCTestCase {
    func testStreakDayAndSummary() {
        let now = Date()
        let dayEmpty = StreakDay(
            date: now,
            firstPhotoURL: nil,
            firstThumbnailURL: nil,
            photoCount: 0
        )
        XCTAssertEqual(dayEmpty.id, now)
        XCTAssertFalse(dayEmpty.hasPhoto)
        
        let dayWithPhoto = StreakDay(
            date: now,
            firstPhotoURL: URL(string: "https://example.com/p.jpg"),
            firstThumbnailURL: nil,
            photoCount: 3
        )
        XCTAssertTrue(dayWithPhoto.hasPhoto)
        
        let summary = StreakSummary(currentStreak: 7, hasTodayPhoto: true)
        XCTAssertEqual(summary.currentStreak, 7)
        XCTAssertTrue(summary.hasTodayPhoto)
    }

    func testGroupAndGroupExpenseSummary() {
        let groupId = UUID()
        let creatorId = UUID()
        let member = UserSummary(id: creatorId, username: "creator", displayName: "Creator")
        
        let group = Group(
            id: groupId,
            name: "Roommates",
            inviteCode: "ABC12345",
            members: [member],
            createdBy: creatorId
        )
        XCTAssertEqual(group.name, "Roommates")
        XCTAssertEqual(group.memberCount, 1)
        
        let item = GroupExpenseItem(
            groupId: groupId,
            groupName: "Roommates",
            groupAvatarURL: nil,
            totalGroupSpending: 1_000_000,
            userPaidTotal: 600_000,
            userBalance: 100_000,
            currency: "VND",
            memberAvatars: [member]
        )
        XCTAssertEqual(item.id, groupId)
        
        let summary = GroupExpenseSummary(groups: [item])
        XCTAssertEqual(summary.groups.count, 1)
    }

    func testMonthlyExpenseSummary() {
        let current = MonthData(
            year: 2026,
            month: 9,
            totalSettledReceived: 500_000,
            totalSettledPaid: 200_000
        )
        XCTAssertEqual(current.id, "2026-9")
        
        let summary = MonthlyExpenseSummary(
            currency: "VND",
            currentMonth: current,
            months: [current]
        )
        XCTAssertEqual(summary.currency, "VND")
        XCTAssertEqual(summary.months.count, 1)
    }

    func testExpenseNettingAndBulkSettlement() {
        let counterparty = UserSummary(id: UUID(), username: "cp", displayName: "Counterparty")
        let settlementId = UUID()
        
        let bulk = BulkSettlement(
            id: settlementId,
            debtorUserId: UUID(),
            creditorUserId: UUID(),
            amount: 250_000,
            currency: "VND",
            evidenceURL: URL(string: "https://example.com/receipt.jpg")!,
            status: .pending,
            splitCount: 3,
            createdAt: Date()
        )
        XCTAssertEqual(bulk.id, settlementId)
        XCTAssertEqual(bulk.status, .pending)
        
        let netting = NettingSummary(
            counterparty: counterparty,
            actorOwesTotal: 100_000,
            counterpartyOwesTotal: 250_000,
            netAmount: 150_000,
            netDirection: .counterpartyOwes,
            currency: "VND",
            unpaidSplitCount: 3,
            expensesInvolved: 2,
            pendingSettlement: bulk
        )
        XCTAssertEqual(netting.netDirection, .counterpartyOwes)
        XCTAssertEqual(netting.pendingSettlement?.amount, 250_000)
    }

    func testAppNotificationNavigationTargetAndMarkRead() {
        let refId = UUID()
        let actorId = UUID()
        let notif = AppNotification(
            id: UUID(),
            type: .feedTaggedInPost,
            title: "Tagged",
            body: "You were tagged in a post",
            referenceId: refId,
            actorUserId: actorId
        )
        XCTAssertFalse(notif.isRead)
        XCTAssertEqual(notif.navigationTarget, .post(refId, commentId: nil))
        
        let readNotif = notif.markingAsRead()
        XCTAssertTrue(readNotif.isRead)
        
        let friendReqNotif = AppNotification(
            id: UUID(),
            type: .friendRequestSent,
            title: "Friend Request",
            body: "Sent you a request",
            referenceId: refId,
            actorUserId: actorId
        )
        XCTAssertTrue(friendReqNotif.canRespondToFriendRequest)
        XCTAssertEqual(friendReqNotif.navigationTarget, .userProfile(actorId))
    }
}
