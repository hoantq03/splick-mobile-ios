import Foundation

public struct ExpenseOverview: Equatable, Sendable {
  public let balance: ExpenseBalanceSection
  public let needsAttention: ExpenseNeedsAttentionSection
  public let recentExpenses: [RecentExpenseItem]
  public let totalSpending: ExpenseTotalSpendingSection

  public init(
    balance: ExpenseBalanceSection,
    needsAttention: ExpenseNeedsAttentionSection,
    recentExpenses: [RecentExpenseItem],
    totalSpending: ExpenseTotalSpendingSection
  ) {
    self.balance = balance
    self.needsAttention = needsAttention
    self.recentExpenses = recentExpenses
    self.totalSpending = totalSpending
  }
}

public struct ExpenseBalanceSection: Equatable, Sendable {
  public let youOwe: Decimal
  public let owedToYou: Decimal
  public let netBalance: Decimal
  public let currency: String
  public let topBalances: [DebtSummary]

  public init(
    youOwe: Decimal,
    owedToYou: Decimal,
    netBalance: Decimal,
    currency: String,
    topBalances: [DebtSummary]
  ) {
    self.youOwe = youOwe
    self.owedToYou = owedToYou
    self.netBalance = netBalance
    self.currency = currency
    self.topBalances = topBalances
  }
}

public enum ExpenseNeedsAttentionType: String, Equatable, Sendable {
  case paymentRequest = "PAYMENT_REQUEST"
  case expenseConfirmation = "EXPENSE_CONFIRMATION"
  case outstandingSettlement = "OUTSTANDING_SETTLEMENT"
}

public struct ExpenseNeedsAttentionSection: Equatable, Sendable {
  public let pendingPaymentRequestCount: Int
  public let expensesNeedingConfirmationCount: Int
  public let outstandingSettlementCount: Int
  public let totalActionItems: Int
  public let items: [ExpenseNeedsAttentionItem]

  public init(
    pendingPaymentRequestCount: Int,
    expensesNeedingConfirmationCount: Int,
    outstandingSettlementCount: Int,
    totalActionItems: Int,
    items: [ExpenseNeedsAttentionItem]
  ) {
    self.pendingPaymentRequestCount = pendingPaymentRequestCount
    self.expensesNeedingConfirmationCount = expensesNeedingConfirmationCount
    self.outstandingSettlementCount = outstandingSettlementCount
    self.totalActionItems = totalActionItems
    self.items = items
  }
}

public struct ExpenseNeedsAttentionItem: Identifiable, Equatable, Sendable {
  public let type: ExpenseNeedsAttentionType
  public let id: UUID
  public let title: String
  public let amount: Decimal
  public let currency: String
  public let counterparty: UserSummary?
  public let createdAt: Date

  public init(
    type: ExpenseNeedsAttentionType,
    id: UUID,
    title: String,
    amount: Decimal,
    currency: String,
    counterparty: UserSummary?,
    createdAt: Date
  ) {
    self.type = type
    self.id = id
    self.title = title
    self.amount = amount
    self.currency = currency
    self.counterparty = counterparty
    self.createdAt = createdAt
  }
}

public struct RecentExpenseItem: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let description: String
  public let amount: Decimal
  public let currency: String
  public let category: ExpenseCategory
  public let paidBy: UserSummary
  public let participants: [UserSummary]
  public let createdAt: Date
  public let groupId: UUID?

  public init(
    id: UUID,
    description: String,
    amount: Decimal,
    currency: String,
    category: ExpenseCategory,
    paidBy: UserSummary,
    participants: [UserSummary],
    createdAt: Date,
    groupId: UUID?
  ) {
    self.id = id
    self.description = description
    self.amount = amount
    self.currency = currency
    self.category = category
    self.paidBy = paidBy
    self.participants = participants
    self.createdAt = createdAt
    self.groupId = groupId
  }
}

public struct ExpenseTotalSpendingSection: Equatable, Sendable {
  public let currentPeriodTotal: Decimal
  public let previousPeriodTotal: Decimal
  public let percentageChange: Decimal
  public let currency: String

  public init(
    currentPeriodTotal: Decimal,
    previousPeriodTotal: Decimal,
    percentageChange: Decimal,
    currency: String
  ) {
    self.currentPeriodTotal = currentPeriodTotal
    self.previousPeriodTotal = previousPeriodTotal
    self.percentageChange = percentageChange
    self.currency = currency
  }
}
