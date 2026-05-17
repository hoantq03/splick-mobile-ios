import Foundation

public struct Expense: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let description: String
    public let totalAmount: Decimal
    public let currency: String
    public let paidBy: UserSummary
    public let splits: [ExpenseSplit]
    public let groupId: UUID?
    public let category: ExpenseCategory
    public let status: ExpenseStatus
    public let createdAt: Date

    public init(
        id: UUID,
        description: String,
        totalAmount: Decimal,
        currency: String = "VND",
        paidBy: UserSummary,
        splits: [ExpenseSplit] = [],
        groupId: UUID? = nil,
        category: ExpenseCategory = .general,
        status: ExpenseStatus = .pending,
        createdAt: Date = .now
    ) {
        self.id = id
        self.description = description
        self.totalAmount = totalAmount
        self.currency = currency
        self.paidBy = paidBy
        self.splits = splits
        self.groupId = groupId
        self.category = category
        self.status = status
        self.createdAt = createdAt
    }
}

public struct ExpenseSplit: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let user: UserSummary
    public let amount: Decimal
    public let isPaid: Bool

    public init(id: UUID, user: UserSummary, amount: Decimal, isPaid: Bool = false) {
        self.id = id
        self.user = user
        self.amount = amount
        self.isPaid = isPaid
    }
}

public enum ExpenseCategory: String, Codable, CaseIterable, Sendable {
    case food = "FOOD"
    case transport = "TRANSPORT"
    case housing = "HOUSING"
    case entertainment = "ENTERTAINMENT"
    case shopping = "SHOPPING"
    case utilities = "UTILITIES"
    case travel = "TRAVEL"
    case general = "GENERAL"

    public var displayName: String {
        switch self {
        case .food: return "Food & Drinks"
        case .transport: return "Transport"
        case .housing: return "Housing"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .utilities: return "Utilities"
        case .travel: return "Travel"
        case .general: return "General"
        }
    }

    public var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .housing: return "house.fill"
        case .entertainment: return "film.fill"
        case .shopping: return "bag.fill"
        case .utilities: return "bolt.fill"
        case .travel: return "airplane"
        case .general: return "dollarsign.circle.fill"
        }
    }
}

public enum ExpenseStatus: String, Codable, Sendable {
    case pending = "PENDING"
    case partiallySettled = "PARTIALLY_SETTLED"
    case settled = "SETTLED"
}

public struct DebtSummary: Codable, Equatable, Sendable {
    public let user: UserSummary
    public let amount: Decimal
    public let currency: String

    public init(user: UserSummary, amount: Decimal, currency: String = "VND") {
        self.user = user
        self.amount = amount
        self.currency = currency
    }

    public var isOwed: Bool { amount > 0 }
    public var owes: Bool { amount < 0 }
}
