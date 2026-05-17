import Foundation
import SplickDomain

public protocol ExpenseRepositoryProtocol: Sendable {
    func fetchExpenses(groupId: UUID?, page: Int, limit: Int) async throws -> [Expense]
    func fetchExpense(id: UUID) async throws -> Expense
    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense
    func settleExpense(expenseId: UUID, splitId: UUID) async throws
    func fetchDebtSummary(groupId: UUID?) async throws -> [DebtSummary]
}

public struct CreateExpenseRequest: Sendable {
    public let description: String
    public let totalAmount: Decimal
    public let currency: String
    public let groupId: UUID?
    public let category: ExpenseCategory
    public let splitType: SplitType
    public let participants: [UUID]
    public let customAmounts: [UUID: Decimal]?

    public init(
        description: String,
        totalAmount: Decimal,
        currency: String = "VND",
        groupId: UUID? = nil,
        category: ExpenseCategory = .general,
        splitType: SplitType = .equal,
        participants: [UUID],
        customAmounts: [UUID: Decimal]? = nil
    ) {
        self.description = description
        self.totalAmount = totalAmount
        self.currency = currency
        self.groupId = groupId
        self.category = category
        self.splitType = splitType
        self.participants = participants
        self.customAmounts = customAmounts
    }
}

public enum SplitType: String, Codable, CaseIterable, Sendable {
    case equal = "EQUAL"
    case exact = "EXACT"
    case percentage = "PERCENTAGE"

    public var displayName: String {
        switch self {
        case .equal: return "Split Equally"
        case .exact: return "Exact Amounts"
        case .percentage: return "By Percentage"
        }
    }
}
