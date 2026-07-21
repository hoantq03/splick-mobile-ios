import Foundation
import SplickDomain
import FeatureExpense
import Common

public actor FakeExpenseRepository: ExpenseRepositoryProtocol {
    private var expenses: [Expense] = []
    private let logger: StateLogger

    private let currentUser = UserSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "namtran", displayName: "Nam Tran", avatarURL: nil
    )

    private let friend1 = UserSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        username: "linhpham", displayName: "Linh Pham", avatarURL: nil
    )

    private let friend2 = UserSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        username: "ducnguyen", displayName: "Duc Nguyen", avatarURL: nil
    )

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        let grabSettledAt = Date().addingTimeInterval(-82800)
        let internetPartialPaidAt = Date().addingTimeInterval(-86400)

        expenses = [
            Expense(
                id: UUID(), description: "Korean BBQ dinner",
                totalAmount: 450000, currency: "VND",
                paidBy: friend1,
                splits: [
                    ExpenseSplit(id: UUID(), user: currentUser, amount: 150000, isPaid: false),
                    ExpenseSplit(
                        id: UUID(), user: friend1, amount: 150000, isPaid: true,
                        paidAt: Date().addingTimeInterval(-3500)
                    ),
                    ExpenseSplit(id: UUID(), user: friend2, amount: 150000, isPaid: false),
                ],
                category: .food, status: .pending,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            Expense(
                id: UUID(), description: "Grab to District 1",
                totalAmount: 85000, currency: "VND",
                paidBy: currentUser,
                splits: [
                    ExpenseSplit(
                        id: UUID(), user: friend1, amount: 42500, isPaid: true, paidAt: grabSettledAt
                    ),
                    ExpenseSplit(
                        id: UUID(), user: currentUser, amount: 42500, isPaid: true, paidAt: grabSettledAt
                    ),
                ],
                category: .transport, status: .settled,
                createdAt: Date().addingTimeInterval(-86400),
                settledAt: grabSettledAt
            ),
            Expense(
                id: UUID(), description: "Monthly internet bill",
                totalAmount: 300000, currency: "VND",
                paidBy: friend2,
                splits: [
                    ExpenseSplit(id: UUID(), user: currentUser, amount: 100000, isPaid: false),
                    ExpenseSplit(
                        id: UUID(), user: friend1, amount: 100000, isPaid: true, paidAt: internetPartialPaidAt
                    ),
                    ExpenseSplit(
                        id: UUID(), user: friend2, amount: 100000, isPaid: true,
                        paidAt: Date().addingTimeInterval(-170000)
                    ),
                ],
                category: .utilities, status: .partiallySettled,
                createdAt: Date().addingTimeInterval(-172800)
            ),
        ]

        logger.log("Seeded \(expenses.count) expenses")
    }

    public func fetchExpenses(groupId: UUID?, page: Int, limit: Int) async throws -> [Expense] {
        logger.log("Fetch expenses: page=\(page), limit=\(limit), groupId=\(groupId?.uuidString.prefix(8) ?? "nil")")
        try await Task.sleep(for: .milliseconds(400))

        var filtered = expenses
        if let groupId {
            filtered = filtered.filter { $0.groupId == groupId }
        }

        let start = page * limit
        guard start < filtered.count else { return [] }
        let end = min(start + limit, filtered.count)
        let result = Array(filtered[start..<end])

        logger.success("Loaded \(result.count) expenses")
        return result
    }

    public func fetchExpense(id: UUID) async throws -> Expense {
        logger.log("Fetch expense: \(id)")
        guard let expense = expenses.first(where: { $0.id == id }) else {
            throw NetworkError.notFound
        }
        return expense
    }

    public func createExpense(_ request: CreateExpenseRequest) async throws -> Expense {
        logger.log("Create expense: '\(request.description)' = \(request.totalAmount) \(request.currency)")
        logger.log("  Split type: \(request.splitType.rawValue), participants: \(request.participants.count)")
        try await Task.sleep(for: .milliseconds(600))

        let splitAmount = request.totalAmount / Decimal(request.participants.count)
        let splits = request.participants.map { userId in
            ExpenseSplit(
                id: UUID(),
                user: UserSummary(id: userId, username: "user_\(userId.uuidString.prefix(4))", displayName: "User", avatarURL: nil),
                amount: splitAmount,
                isPaid: false
            )
        }

        logger.log("  Calculated splits: \(splits.map { "\($0.amount)" }.joined(separator: ", "))")

        let expense = Expense(
            id: UUID(),
            description: request.description,
            totalAmount: request.totalAmount,
            currency: request.currency,
            paidBy: currentUser,
            splits: splits,
            groupId: request.groupId,
            category: request.category,
            status: .pending,
            createdAt: .now
        )
        expenses.insert(expense, at: 0)

        logger.success("Expense created: \(expense.id)")
        return expense
    }

    public func settleExpense(expenseId: UUID, splitId: UUID) async throws {
        logger.log("Settle: expense=\(expenseId.uuidString.prefix(8)), split=\(splitId.uuidString.prefix(8))")
        try await Task.sleep(for: .milliseconds(300))
        logger.success("Split marked as paid")
    }

    public func fetchDebtSummary(groupId: UUID?) async throws -> [DebtSummary] {
        logger.log("Fetch debt summary")
        try await Task.sleep(for: .milliseconds(300))

        let debts = [
            DebtSummary(user: friend1, amount: 150000, currency: "VND"),
            DebtSummary(user: friend2, amount: -100000, currency: "VND"),
        ]

        logger.success("Debts: owed=150,000₫, owing=100,000₫")
        return debts
    }

    public func fetchExpenses(
        counterpartyId: UUID,
        page: Int,
        limit: Int,
        status: CounterpartyExpenseStatus
    ) async throws -> ExpensePage {
        let matching = expenses.filter { expense in
            expense.paidBy.id == counterpartyId
                || expense.splits.contains { $0.user.id == counterpartyId }
        }
        let start = page * limit
        let pageExpenses = start < matching.count
            ? Array(matching[start..<min(start + limit, matching.count)])
            : []
        return ExpensePage(
            expenses: pageExpenses,
            page: page,
            totalPages: max(1, Int(ceil(Double(matching.count) / Double(limit)))),
            totalItems: matching.count,
            hasNext: start + limit < matching.count
        )
    }

    public func fetchNetting(counterpartyId: UUID) async throws -> NettingSummary {
        let counterparty = counterpartyId == friend1.id ? friend1 : friend2
        return NettingSummary(
            counterparty: counterparty,
            actorOwesTotal: counterpartyId == friend2.id ? 100000 : 0,
            counterpartyOwesTotal: counterpartyId == friend1.id ? 150000 : 0,
            netAmount: counterpartyId == friend1.id ? 150000 : 100000,
            netDirection: counterpartyId == friend1.id ? .counterpartyOwes : .actorOwes,
            currency: "VND",
            unpaidSplitCount: 1,
            expensesInvolved: 1
        )
    }

    public func submitBulkSettlement(
        counterpartyId: UUID,
        evidenceURL: URL,
        note: String?
    ) async throws -> BulkSettlement {
        BulkSettlement(
            id: UUID(),
            debtorUserId: currentUser.id,
            creditorUserId: counterpartyId,
            amount: 100000,
            currency: "VND",
            evidenceURL: evidenceURL,
            note: note,
            status: .pending,
            splitCount: 1,
            createdAt: .now
        )
    }

    public func approveBulkSettlement(id: UUID) async throws -> BulkSettlement {
        BulkSettlement(
            id: id,
            debtorUserId: currentUser.id,
            creditorUserId: friend1.id,
            amount: 100000,
            currency: "VND",
            evidenceURL: URL(string: "https://example.com/evidence.jpg")!,
            status: .approved,
            splitCount: 1,
            createdAt: .now,
            reviewedAt: .now
        )
    }

    public func rejectBulkSettlement(id: UUID, reason: String?) async throws -> BulkSettlement {
        BulkSettlement(
            id: id,
            debtorUserId: currentUser.id,
            creditorUserId: friend1.id,
            amount: 100000,
            currency: "VND",
            evidenceURL: URL(string: "https://example.com/evidence.jpg")!,
            note: reason,
            status: .rejected,
            splitCount: 1,
            createdAt: .now,
            reviewedAt: .now,
            rejectReason: reason
        )
    }
}
