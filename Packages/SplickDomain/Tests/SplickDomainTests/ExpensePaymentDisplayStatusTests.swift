import Foundation
import XCTest
@testable import SplickDomain

final class ExpensePaymentDisplayStatusTests: XCTestCase {
    private let me = UserSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "me",
        displayName: "Me",
        avatarURL: nil
    )
    private let friend = UserSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        username: "friend",
        displayName: "Friend",
        avatarURL: nil
    )
    private let other = UserSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        username: "other",
        displayName: "Other",
        avatarURL: nil
    )

    func testPendingSplitIsPendingApprovalForDebtorAndPayer() {
        let expense = expense(
            paidBy: friend,
            splits: [
                ExpenseSplit(id: UUID(), user: friend, amount: 50, isPaid: true, paymentStatus: .paid),
                ExpenseSplit(
                    id: UUID(),
                    user: me,
                    amount: 50,
                    isPaid: false,
                    paymentStatus: .pendingApproval
                ),
            ]
        )
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: me.id), .pendingApproval)
        XCTAssertEqual(expense.userDebtState(userId: me.id), .oweUnpaid)
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: friend.id), .pendingApproval)
        XCTAssertTrue(expense.hasPendingPaymentEvidence(userId: me.id))
        XCTAssertTrue(expense.hasPendingPaymentEvidence(userId: friend.id))
    }

    func testPaidSplitIsPaidDisplayStatus() {
        let expense = expense(
            paidBy: friend,
            splits: [
                ExpenseSplit(id: UUID(), user: friend, amount: 50, isPaid: true, paymentStatus: .paid),
                ExpenseSplit(id: UUID(), user: me, amount: 50, isPaid: true, paymentStatus: .paid),
            ],
            status: .settled
        )
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: me.id), .paid)
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: friend.id), .paid)
    }

    func testPayerWithMixedUnpaidAndPendingIsPendingApproval() {
        let expense = expense(
            paidBy: me,
            splits: [
                ExpenseSplit(
                    id: UUID(),
                    user: friend,
                    amount: 50,
                    isPaid: false,
                    paymentStatus: .pendingApproval
                ),
                ExpenseSplit(
                    id: UUID(),
                    user: other,
                    amount: 50,
                    isPaid: false,
                    paymentStatus: .unpaid
                ),
            ]
        )
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: me.id), .pendingApproval)
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: other.id), .unpaid)
        XCTAssertTrue(expense.awaitingMyPaymentApproval(userId: me.id))
        XCTAssertFalse(expense.awaitingMyPaymentApproval(userId: other.id))
    }

    func testGuestPendingSplitIsAwaitingHostApproval() {
        let guest = UserSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            username: "guest",
            displayName: "Guest",
            avatarURL: nil
        )
        let expense = expense(
            paidBy: me,
            splits: [
                ExpenseSplit(
                    id: UUID(),
                    user: guest,
                    amount: 100,
                    isPaid: false,
                    paymentStatus: .pendingApproval
                ),
            ]
        )
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: me.id), .pendingApproval)
        XCTAssertTrue(expense.awaitingMyPaymentApproval(userId: me.id))
    }

    func testOmittingPaymentStatusWhenRebuildingSplitDropsPendingApproval() {
        let pending = ExpenseSplit(
            id: UUID(),
            user: me,
            amount: 50,
            isPaid: false,
            paymentStatus: .pendingApproval
        )
        let rebuilt = ExpenseSplit(
            id: pending.id,
            user: pending.user,
            amount: pending.amount,
            isPaid: pending.isPaid,
            paidAt: pending.paidAt
        )
        XCTAssertEqual(pending.paymentStatus, .pendingApproval)
        XCTAssertEqual(rebuilt.paymentStatus, .unpaid)
        let preserved = ExpenseSplit(
            id: pending.id,
            user: pending.user,
            amount: pending.amount,
            isPaid: pending.isPaid,
            paidAt: pending.paidAt,
            paymentStatus: pending.paymentStatus
        )
        XCTAssertEqual(preserved.paymentStatus, .pendingApproval)
    }

    private func expense(
        paidBy: UserSummary,
        splits: [ExpenseSplit],
        status: ExpenseStatus = .pending
    ) -> Expense {
        Expense(
            id: UUID(),
            description: "Lunch",
            totalAmount: 100,
            paidBy: paidBy,
            splits: splits,
            category: .food,
            status: status,
            createdAt: Date()
        )
    }
}
