import Foundation

struct ExpenseResponseDTO: Decodable {
  let id: UUID
  let description: String
  let totalAmount: String
  let currency: String
  let paidBy: ExpenseUserDTO
  let splits: [ExpenseSplitDTO]
  let groupId: UUID?
  let postId: UUID?
  let category: String
  let status: String
  let createdAt: Date
  let settledAt: Date?
}

struct ExpenseUserDTO: Decodable {
  let id: UUID?
  let username: String?
  let displayName: String
  let avatarUrl: String?
}

struct ExpenseSplitDTO: Decodable {
  let id: UUID
  let user: ExpenseUserDTO?
  let amount: String
  let isPaid: Bool
  let paidAt: Date?
  let paymentStatus: String?
  let guestDisplayName: String?
  let inviteUrl: String?
}

struct ClaimBillInviteResponseDTO: Decodable {
  let expenseId: UUID
  let postId: UUID?
  let splitId: UUID
}

struct ClaimBillInviteRequestDTO: Encodable {
  let splitId: UUID
}

struct CreateExpenseRequestDTO: Encodable {
  let description: String
  let totalAmount: String
  let currency: String
  let groupId: UUID?
  let category: String
  let splitType: String
  let participants: [UUID]
  let customAmounts: [String: String]?
}

struct DebtSummaryDTO: Decodable {
  let user: ExpenseUserDTO
  let amount: String
  let currency: String
}

struct DebtSummaryPageDTO: Decodable {
  let content: [DebtSummaryDTO]
}

struct SettleExpenseRequestDTO: Encodable {
  let splitId: UUID
}

struct NettingSummaryDTO: Decodable {
  let counterparty: ExpenseUserDTO
  let actorOwesTotal: String
  let counterpartyOwesTotal: String
  let netAmount: String
  let netDirection: String
  let currency: String
  let unpaidSplitCount: Int
  let expensesInvolved: Int
  let pendingSettlement: BulkSettlementDTO?
}

struct BulkSettlementDTO: Decodable {
  let id: UUID
  let debtorUserId: UUID
  let creditorUserId: UUID
  let amount: String
  let currency: String
  let evidenceUrl: String
  let note: String?
  let status: String
  let splitCount: Int
  let createdAt: Date
  let reviewedAt: Date?
  let rejectReason: String?
}

struct ExpensePageResponseDTO<T: Decodable>: Decodable {
  let content: [T]
  let page: Int
  let limit: Int
  let totalElements: Int64
  let totalPages: Int
  let nextCursor: String?

  var clampedTotalElements: Int {
    max(0, Int(clamping: totalElements))
  }

  var hasNext: Bool {
    if let nextCursor, !nextCursor.isEmpty {
      return true
    }
    return page >= 0 && totalPages > 0 && page < totalPages - 1
  }
}

struct SubmitBulkSettlementRequestDTO: Encodable {
  let evidenceUrl: String
  let note: String?
}

struct RejectBulkSettlementRequestDTO: Encodable {
  let reason: String?
}

struct MonthlyExpenseSummaryDTO: Decodable {
  let currency: String
  let currentMonth: MonthDataDTO
  let months: [MonthDataDTO]
}

struct MonthDataDTO: Decodable {
  let year: Int
  let month: Int
  let totalSettledReceived: String
  let totalSettledPaid: String
}

struct ExpenseOverviewDTO: Decodable {
  let balance: ExpenseBalanceSectionDTO
  let needsAttention: ExpenseNeedsAttentionSectionDTO
  let recentExpenses: [RecentExpenseItemDTO]
  let totalSpending: ExpenseTotalSpendingSectionDTO
}

struct ExpenseBalanceSectionDTO: Decodable {
  let youOwe: String
  let owedToYou: String
  let netBalance: String
  let currency: String
  let topBalances: [DebtSummaryDTO]
}

struct ExpenseNeedsAttentionSectionDTO: Decodable {
  let pendingPaymentRequestCount: Int
  let expensesNeedingConfirmationCount: Int
  let outstandingSettlementCount: Int
  let totalActionItems: Int
  let items: [ExpenseNeedsAttentionItemDTO]
}

struct ExpenseNeedsAttentionItemDTO: Decodable {
  let type: String
  let id: UUID
  let title: String
  let amount: String
  let currency: String
  let counterparty: ExpenseUserDTO?
  let createdAt: Date
}

struct RecentExpenseItemDTO: Decodable {
  let id: UUID
  let description: String
  let amount: String
  let currency: String
  let category: String
  let paidBy: ExpenseUserDTO
  let participants: [ExpenseUserDTO]
  let createdAt: Date
  let groupId: UUID?
}

struct ExpenseTotalSpendingSectionDTO: Decodable {
  let currentPeriodTotal: String
  let previousPeriodTotal: String
  let percentageChange: String
  let currency: String
}

struct SpendingAnalyticsDTO: Decodable {
  let trend: [SpendingTrendPointDTO]
  let categories: [SpendingCategoryBreakdownDTO]
  let currency: String
}

struct SpendingTrendPointDTO: Decodable {
  let bucketStart: Date
  let amount: String
}

struct SpendingCategoryBreakdownDTO: Decodable {
  let category: String
  let amount: String
  let percentage: String
}

struct GroupExpenseSummaryDTO: Decodable {
  let groups: [GroupExpenseItemDTO]
}

struct GroupExpenseItemDTO: Decodable {
  let groupId: UUID
  let groupName: String
  let groupAvatarUrl: String?
  let totalGroupSpending: String
  let userPaidTotal: String
  let userBalance: String
  let currency: String
  let memberAvatars: [ExpenseUserDTO]
}
