import Foundation

public struct Expense: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let description: String
    public let totalAmount: Decimal
    public let currency: String
    public let paidBy: UserSummary
    public let splits: [ExpenseSplit]
    public let groupId: UUID?
    public let postId: UUID?
    public let category: ExpenseCategory
    public let status: ExpenseStatus
    public let createdAt: Date
    /// When the expense was fully settled (nil if still open).
    public let settledAt: Date?

    public init(
        id: UUID,
        description: String,
        totalAmount: Decimal,
        currency: String = "VND",
        paidBy: UserSummary,
        splits: [ExpenseSplit] = [],
        groupId: UUID? = nil,
        postId: UUID? = nil,
        category: ExpenseCategory = .general,
        status: ExpenseStatus = .pending,
        createdAt: Date = .now,
        settledAt: Date? = nil
    ) {
        self.id = id
        self.description = description
        self.totalAmount = totalAmount
        self.currency = currency
        self.paidBy = paidBy
        self.splits = splits
        self.groupId = groupId
        self.postId = postId
        self.category = category
        self.status = status
        self.createdAt = createdAt
        self.settledAt = settledAt
    }

    /// Latest payment timestamp across splits, or explicit `settledAt`.
    public var displaySettledAt: Date? {
        if let settledAt { return settledAt }
        let paidDates = splits.compactMap(\.paidAt)
        return paidDates.max()
    }

    /// Whether the given user has no outstanding share (payer or marked paid on their split).
    public func isPaidFor(userId: UUID?) -> Bool {
        guard let userId else { return status == .settled }
        if paidBy.id == userId { return true }
        if let split = splits.first(where: { $0.user.id == userId }) {
            return split.isPaid
        }
        return status == .settled
    }

    /// Signed cash-flow for list rows: paying others (−) vs being repaid (+).
    public func userCashFlow(userId: UUID?) -> ExpenseUserCashFlow {
        guard let userId else {
            return ExpenseUserCashFlow(direction: .neutral, amount: totalAmount)
        }

        if paidBy.id == userId {
            let fromOthers = splits.filter { $0.user.id != userId }
            let amount = fromOthers.reduce(Decimal.zero) { $0 + $1.amount }
            if amount > 0 {
                return ExpenseUserCashFlow(direction: .receiving, amount: amount)
            }
            return ExpenseUserCashFlow(direction: .neutral, amount: totalAmount)
        }

        if let split = splits.first(where: { $0.user.id == userId }) {
            return ExpenseUserCashFlow(direction: .paying, amount: split.amount)
        }

        return ExpenseUserCashFlow(direction: .neutral, amount: totalAmount)
    }

    /// User-centric debt state for list rows, filters, and overview.
    public func userDebtState(userId: UUID?) -> ExpenseUserDebtState {
        guard let userId else { return status == .settled ? .owePaid : .oweUnpaid }

        if paidBy.id == userId {
            let otherSplits = splits.filter { $0.user.id != userId }
            guard !otherSplits.isEmpty else { return .neutral }
            return otherSplits.allSatisfy(\.isPaid) ? .owedPaid : .owedUnpaid
        }

        if let split = splits.first(where: { $0.user.id == userId }) {
            return split.isPaid ? .owePaid : .oweUnpaid
        }

        return .neutral
    }

    /// Payment status for list-row icons (unpaid, pending approval, paid).
    public func userPaymentDisplayStatus(userId: UUID?) -> ExpensePaymentDisplayStatus {
        guard let userId else {
            return status == .settled ? .paid : .unpaid
        }

        if paidBy.id == userId {
            let others = splits.filter { $0.user.id != userId }
            guard !others.isEmpty else { return .neutral }
            if others.allSatisfy(\.isPaid) { return .paid }
            if others.contains(where: { $0.paymentStatus == .pendingApproval }) {
                return .pendingApproval
            }
            return .unpaid
        }

        if let split = splits.first(where: { $0.user.id == userId }) {
            if split.isPaid { return .paid }
            if split.paymentStatus == .pendingApproval { return .pendingApproval }
            return .unpaid
        }

        return .neutral
    }

    /// Amount attributed to the current user for overview totals in a given debt state.
    public func userDebtAmount(userId: UUID?, state: ExpenseUserDebtState) -> Decimal {
        guard userDebtState(userId: userId) == state else { return .zero }
        return userCashFlow(userId: userId).amount
    }
}

public enum ExpenseUserDebtState: String, CaseIterable, Sendable {
    case oweUnpaid
    case owePaid
    case owedUnpaid
    case owedPaid
    case neutral

    public var isSettled: Bool {
        switch self {
        case .owePaid, .owedPaid, .neutral:
            return true
        case .oweUnpaid, .owedUnpaid:
            return false
        }
    }
}

public enum ExpensePaymentDisplayStatus: Sendable {
    case unpaid
    case pendingApproval
    case paid
    case neutral
}

public struct ExpenseUserCashFlow: Equatable, Sendable {
    public enum Direction: Sendable {
        case receiving
        case paying
        case neutral
    }

    public let direction: Direction
    public let amount: Decimal

    public init(direction: Direction, amount: Decimal) {
        self.direction = direction
        self.amount = amount
    }
}

public struct ExpenseSplit: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let user: UserSummary
    public let amount: Decimal
    public let isPaid: Bool
    public let paidAt: Date?
    public let paymentStatus: PaymentSplitStatus

    public init(
        id: UUID,
        user: UserSummary,
        amount: Decimal,
        isPaid: Bool = false,
        paidAt: Date? = nil,
        paymentStatus: PaymentSplitStatus? = nil
    ) {
        self.id = id
        self.user = user
        self.amount = amount
        self.isPaid = isPaid
        self.paidAt = paidAt
        if let paymentStatus {
            self.paymentStatus = paymentStatus
        } else {
            self.paymentStatus = isPaid ? .paid : .unpaid
        }
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

    /// English-only fallback. Domain layer has no access to `LanguageService`;
    /// UI call sites must use `ExpenseCategory.title(using:)` from `FeatureExpense`'s
    /// `ExpenseL10n` instead so labels are localized.
    @available(*, deprecated, message: "Use ExpenseCategory.title(using:) for localized UI text.")
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
