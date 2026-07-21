import Foundation
import SplickDomain

enum ExpenseMapper {
  static func toExpense(_ dto: ExpenseResponseDTO) -> Expense {
    Expense(
      id: dto.id,
      description: dto.description,
      totalAmount: Decimal(string: dto.totalAmount) ?? 0,
      currency: dto.currency,
      paidBy: toUserSummary(dto.paidBy),
      splits: dto.splits.map(toExpenseSplit),
      groupId: dto.groupId,
      postId: dto.postId,
      category: ExpenseCategory(rawValue: dto.category) ?? .general,
      status: ExpenseStatus(rawValue: dto.status) ?? .pending,
      createdAt: dto.createdAt,
      settledAt: dto.settledAt
    )
  }

  static func toExpenseSplit(_ dto: ExpenseSplitDTO) -> ExpenseSplit {
    ExpenseSplit(
      id: dto.id,
      user: toUserSummary(dto.user),
      amount: Decimal(string: dto.amount) ?? 0,
      isPaid: dto.isPaid,
      paidAt: dto.paidAt
    )
  }

  static func toUserSummary(_ dto: ExpenseUserDTO) -> UserSummary {
    UserSummary(
      id: dto.id,
      username: dto.username,
      displayName: dto.displayName,
      avatarURL: dto.avatarUrl.flatMap(URL.init(string:))
    )
  }

  static func toDebtSummary(_ dto: DebtSummaryDTO) -> DebtSummary {
    DebtSummary(
      user: toUserSummary(dto.user),
      amount: Decimal(string: dto.amount) ?? 0,
      currency: dto.currency
    )
  }

  static func toNettingSummary(_ dto: NettingSummaryDTO) throws -> NettingSummary {
    NettingSummary(
      counterparty: toUserSummary(dto.counterparty),
      actorOwesTotal: Decimal(string: dto.actorOwesTotal) ?? .zero,
      counterpartyOwesTotal: Decimal(string: dto.counterpartyOwesTotal) ?? .zero,
      netAmount: Decimal(string: dto.netAmount) ?? .zero,
      netDirection: NetDirection(rawValue: dto.netDirection) ?? .settled,
      currency: dto.currency,
      unpaidSplitCount: dto.unpaidSplitCount,
      expensesInvolved: dto.expensesInvolved,
      pendingSettlement: try dto.pendingSettlement.map(toBulkSettlement)
    )
  }

  static func toBulkSettlement(_ dto: BulkSettlementDTO) throws -> BulkSettlement {
    guard let evidenceURL = URL(string: dto.evidenceUrl) else {
      throw ExpenseMappingError.invalidEvidenceURL
    }
    guard let status = BulkSettlementStatus(rawValue: dto.status) else {
      throw ExpenseMappingError.invalidBulkSettlementStatus
    }
    return BulkSettlement(
      id: dto.id,
      debtorUserId: dto.debtorUserId,
      creditorUserId: dto.creditorUserId,
      amount: Decimal(string: dto.amount) ?? .zero,
      currency: dto.currency,
      evidenceURL: evidenceURL,
      note: dto.note,
      status: status,
      splitCount: dto.splitCount,
      createdAt: dto.createdAt,
      reviewedAt: dto.reviewedAt,
      rejectReason: dto.rejectReason
    )
  }

  static func toRequestDTO(_ request: CreateExpenseRequest) -> CreateExpenseRequestDTO {
    var customAmountsDTO: [String: String]?
    if let customAmounts = request.customAmounts {
      customAmountsDTO = Dictionary(
        uniqueKeysWithValues: customAmounts.map { ($0.key.uuidString, "\($0.value)") }
      )
    }

    return CreateExpenseRequestDTO(
      description: request.description,
      totalAmount: "\(request.totalAmount)",
      currency: request.currency,
      groupId: request.groupId,
      category: request.category.rawValue,
      splitType: request.splitType.rawValue,
      participants: request.participants,
      customAmounts: customAmountsDTO
    )
  }
}

private enum ExpenseMappingError: Error {
  case invalidEvidenceURL
  case invalidBulkSettlementStatus
}
