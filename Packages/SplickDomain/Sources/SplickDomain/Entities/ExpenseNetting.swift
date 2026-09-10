import Foundation

public struct NettingSummary: Codable, Equatable, Sendable {
  public let counterparty: UserSummary
  public let actorOwesTotal: Decimal
  public let counterpartyOwesTotal: Decimal
  public let netAmount: Decimal
  public let netDirection: NetDirection
  public let currency: String
  public let unpaidSplitCount: Int
  public let expensesInvolved: Int
  public let pendingSettlement: BulkSettlement?

  public init(
    counterparty: UserSummary,
    actorOwesTotal: Decimal,
    counterpartyOwesTotal: Decimal,
    netAmount: Decimal,
    netDirection: NetDirection,
    currency: String,
    unpaidSplitCount: Int,
    expensesInvolved: Int,
    pendingSettlement: BulkSettlement? = nil
  ) {
    self.counterparty = counterparty
    self.actorOwesTotal = actorOwesTotal
    self.counterpartyOwesTotal = counterpartyOwesTotal
    self.netAmount = netAmount
    self.netDirection = netDirection
    self.currency = currency
    self.unpaidSplitCount = unpaidSplitCount
    self.expensesInvolved = expensesInvolved
    self.pendingSettlement = pendingSettlement
  }
}

public enum NetDirection: String, Codable, Sendable {
  case actorOwes = "ACTOR_OWES"
  case counterpartyOwes = "COUNTERPARTY_OWES"
  case settled = "SETTLED"
}

public struct BulkSettlement: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let debtorUserId: UUID
  public let creditorUserId: UUID
  public let amount: Decimal
  public let currency: String
  public let evidenceURL: URL
  public let note: String?
  public let status: BulkSettlementStatus
  public let splitCount: Int
  public let createdAt: Date
  public let reviewedAt: Date?
  public let rejectReason: String?

  public init(
    id: UUID,
    debtorUserId: UUID,
    creditorUserId: UUID,
    amount: Decimal,
    currency: String,
    evidenceURL: URL,
    note: String? = nil,
    status: BulkSettlementStatus,
    splitCount: Int,
    createdAt: Date,
    reviewedAt: Date? = nil,
    rejectReason: String? = nil
  ) {
    self.id = id
    self.debtorUserId = debtorUserId
    self.creditorUserId = creditorUserId
    self.amount = amount
    self.currency = currency
    self.evidenceURL = evidenceURL
    self.note = note
    self.status = status
    self.splitCount = splitCount
    self.createdAt = createdAt
    self.reviewedAt = reviewedAt
    self.rejectReason = rejectReason
  }
}

public enum BulkSettlementStatus: String, Codable, Sendable {
  case pending = "PENDING_APPROVAL"
  case approved = "APPROVED"
  case rejected = "REJECTED"
}
