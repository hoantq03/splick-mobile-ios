import XCTest
@testable import SplickDomain

final class ExpenseDomainRulesTests: XCTestCase {
    func testExpenseUserCalculations() {
        let payer = UserSummary(id: UUID(), username: "payer", displayName: "Payer")
        let friend1 = UserSummary(id: UUID(), username: "f1", displayName: "Friend 1")
        let friend2 = UserSummary(id: UUID(), username: "f2", displayName: "Friend 2")
        let outsider = UUID()
        
        let split1 = ExpenseSplit(id: UUID(), user: friend1, amount: 50_000, isPaid: true)
        let split2 = ExpenseSplit(id: UUID(), user: friend2, amount: 50_000, isPaid: false, paymentStatus: .pendingApproval)
        
        let expense = Expense(
            id: UUID(),
            description: "Dinner",
            totalAmount: 100_000,
            currency: "VND",
            paidBy: payer,
            splits: [split1, split2],
            category: .food,
            status: .pending
        )
        
        // Payer perspective
        XCTAssertTrue(expense.isPaidFor(userId: payer.id))
        let payerFlow = expense.userCashFlow(userId: payer.id)
        XCTAssertEqual(payerFlow.direction, .receiving)
        XCTAssertEqual(payerFlow.amount, 100_000)
        XCTAssertEqual(expense.userDebtState(userId: payer.id), .owedUnpaid)
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: payer.id), .pendingApproval)
        XCTAssertTrue(expense.awaitingMyPaymentApproval(userId: payer.id))
        XCTAssertTrue(expense.hasPendingPaymentEvidence(userId: payer.id))
        XCTAssertEqual(expense.userDebtAmount(userId: payer.id, state: .owedUnpaid), 100_000)
        XCTAssertEqual(expense.userDebtAmount(userId: payer.id, state: .oweUnpaid), .zero)
        
        // Friend 1 perspective (paid)
        XCTAssertTrue(expense.isPaidFor(userId: friend1.id))
        let f1Flow = expense.userCashFlow(userId: friend1.id)
        XCTAssertEqual(f1Flow.direction, .paying)
        XCTAssertEqual(f1Flow.amount, 50_000)
        XCTAssertEqual(expense.userDebtState(userId: friend1.id), .owePaid)
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: friend1.id), .paid)
        
        // Friend 2 perspective (pending approval)
        XCTAssertFalse(expense.isPaidFor(userId: friend2.id))
        XCTAssertEqual(expense.userDebtState(userId: friend2.id), .oweUnpaid)
        XCTAssertEqual(expense.userPaymentDisplayStatus(userId: friend2.id), .pendingApproval)
        XCTAssertFalse(expense.awaitingMyPaymentApproval(userId: friend2.id))
        
        // Outsider / nil perspective
        XCTAssertFalse(expense.isPaidFor(userId: outsider))
        XCTAssertEqual(expense.userDebtState(userId: outsider), .neutral)
        XCTAssertEqual(expense.userCashFlow(userId: outsider).direction, .neutral)
        XCTAssertFalse(expense.isPaidFor(userId: nil))
        XCTAssertEqual(expense.userDebtState(userId: nil), .oweUnpaid)
    }

    func testExpenseOverviewAndDebtSummary() {
        let user = UserSummary(id: UUID(), username: "bob", displayName: "Bob")
        let debtPositive = DebtSummary(user: user, amount: 50_000)
        XCTAssertTrue(debtPositive.isOwed)
        XCTAssertFalse(debtPositive.owes)
        
        let debtNegative = DebtSummary(user: user, amount: -30_000)
        XCTAssertFalse(debtNegative.isOwed)
        XCTAssertTrue(debtNegative.owes)
        
        let balance = ExpenseBalanceSection(
            youOwe: 30_000,
            owedToYou: 50_000,
            netBalance: 20_000,
            currency: "VND",
            topBalances: [debtPositive, debtNegative]
        )
        
        let actionItem = ExpenseNeedsAttentionItem(
            type: .paymentRequest,
            id: UUID(),
            title: "Approve payment",
            amount: 50_000,
            currency: "VND",
            counterparty: user,
            createdAt: Date(),
            postId: nil
        )
        XCTAssertFalse(actionItem.rowIdentity.isEmpty)
        
        let attention = ExpenseNeedsAttentionSection(
            pendingPaymentRequestCount: 1,
            expensesNeedingConfirmationCount: 0,
            outstandingSettlementCount: 0,
            totalActionItems: 1,
            items: [actionItem]
        )
        
        let recent = RecentExpenseItem(
            id: UUID(),
            description: "Coffee",
            amount: 45_000,
            currency: "VND",
            category: .food,
            paidBy: user,
            participants: [user],
            createdAt: Date(),
            groupId: nil
        )
        
        let spending = ExpenseTotalSpendingSection(
            currentPeriodTotal: 100_000,
            previousPeriodTotal: 80_000,
            percentageChange: 25,
            currency: "VND"
        )
        
        let overview = ExpenseOverview(
            balance: balance,
            needsAttention: attention,
            recentExpenses: [recent],
            totalSpending: spending
        )
        
        XCTAssertEqual(overview.balance.netBalance, 20_000)
        XCTAssertEqual(overview.needsAttention.totalActionItems, 1)
        XCTAssertEqual(overview.recentExpenses.count, 1)
    }

    func testExpenseCategoryIcons() {
        for category in ExpenseCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty)
        }
        XCTAssertTrue(ExpenseUserDebtState.owePaid.isSettled)
        XCTAssertFalse(ExpenseUserDebtState.oweUnpaid.isSettled)
    }
}
