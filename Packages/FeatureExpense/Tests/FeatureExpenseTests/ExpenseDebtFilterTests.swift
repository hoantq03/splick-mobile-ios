import Foundation
import SplickDomain
import XCTest
@testable import FeatureExpense

final class ExpenseDebtFilterTests: XCTestCase {
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

    func testUnpaidFilterExcludesPendingApproval() {
        let pending = expense(mePays: false, paid: false, status: .pendingApproval)
        let unpaid = expense(mePays: false, paid: false, status: .unpaid)
        XCTAssertFalse(ExpenseDebtFilter.oweUnpaid.matches(expense: pending, userId: me.id))
        XCTAssertTrue(ExpenseDebtFilter.oweUnpaid.matches(expense: unpaid, userId: me.id))
        XCTAssertTrue(ExpenseDebtFilter.pendingApproval.matches(expense: pending, userId: me.id))
        XCTAssertFalse(ExpenseDebtFilter.awaitingMyReview.matches(expense: pending, userId: me.id))
        XCTAssertFalse(ExpenseDebtFilter.pendingApproval.matches(expense: pending, userId: friend.id))
        XCTAssertTrue(ExpenseDebtFilter.awaitingMyReview.matches(expense: pending, userId: friend.id))
        XCTAssertFalse(ExpenseDebtFilter.pendingApproval.matches(expense: unpaid, userId: me.id))
    }

    func testRepaidFilterMatchesPaidDisplayStatus() {
        let paid = expense(mePays: false, paid: true, status: .paid)
        let unpaid = expense(mePays: false, paid: false, status: .unpaid)
        XCTAssertTrue(ExpenseDebtFilter.repaid.matches(expense: paid, userId: me.id))
        XCTAssertFalse(ExpenseDebtFilter.repaid.matches(expense: unpaid, userId: me.id))
        XCTAssertFalse(ExpenseDebtFilter.pendingApproval.matches(expense: paid, userId: me.id))
    }

    func testOwedUnpaidExcludesPendingWhenOthersOweMe() {
        let pending = expense(mePays: true, paid: false, status: .pendingApproval)
        let unpaid = expense(mePays: true, paid: false, status: .unpaid)
        XCTAssertFalse(ExpenseDebtFilter.owedUnpaid.matches(expense: pending, userId: me.id))
        XCTAssertTrue(ExpenseDebtFilter.owedUnpaid.matches(expense: unpaid, userId: me.id))
        XCTAssertFalse(ExpenseDebtFilter.pendingApproval.matches(expense: pending, userId: me.id))
        XCTAssertTrue(ExpenseDebtFilter.awaitingMyReview.matches(expense: pending, userId: me.id))
    }

    func testHistoryCasesAreSelectableChipsWithoutAll() {
        XCTAssertFalse(ExpenseDebtFilter.historyCases.contains(.all))
        XCTAssertTrue(ExpenseDebtFilter.historyCases.contains(.pendingApproval))
        XCTAssertTrue(ExpenseDebtFilter.historyCases.contains(.awaitingMyReview))
        XCTAssertTrue(ExpenseDebtFilter.historyCases.contains(.repaid))
    }

    func testGuestPendingSplitIsAwaitingHostReviewNotSubmittedChip() {
        let guest = UserSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            username: "guest",
            displayName: "Guest",
            avatarURL: nil
        )
        let expense = Expense(
            id: UUID(),
            description: "Dinner",
            totalAmount: 80,
            paidBy: me,
            splits: [
                ExpenseSplit(
                    id: UUID(),
                    user: guest,
                    amount: 80,
                    isPaid: false,
                    paymentStatus: .pendingApproval
                ),
            ],
            category: .food,
            status: .pending,
            createdAt: Date()
        )
        XCTAssertFalse(ExpenseDebtFilter.pendingApproval.matches(expense: expense, userId: me.id))
        XCTAssertTrue(ExpenseDebtFilter.awaitingMyReview.matches(expense: expense, userId: me.id))
        XCTAssertFalse(ExpenseDebtFilter.awaitingMyReview.matches(expense: expense, userId: friend.id))
    }

    private func expense(
        mePays: Bool,
        paid: Bool,
        status: PaymentSplitStatus
    ) -> Expense {
        let payer = mePays ? me : friend
        let other = mePays ? friend : me
        return Expense(
            id: UUID(),
            description: "Lunch",
            totalAmount: 100,
            paidBy: payer,
            splits: [
                ExpenseSplit(
                    id: UUID(),
                    user: other,
                    amount: 100,
                    isPaid: paid,
                    paymentStatus: status
                ),
            ],
            category: .food,
            status: paid ? .settled : .pending,
            createdAt: Date()
        )
    }
}
