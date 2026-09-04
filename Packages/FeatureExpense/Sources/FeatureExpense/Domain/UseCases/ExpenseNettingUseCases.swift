import Foundation
import SplickDomain

public protocol FetchCounterpartyExpensesUseCaseProtocol: Sendable {
  func execute(
    counterpartyId: UUID,
    page: Int,
    status: CounterpartyExpenseStatus,
    cursor: String?
  ) async throws -> ExpensePage
}

public final class FetchCounterpartyExpensesUseCase:
  FetchCounterpartyExpensesUseCaseProtocol,
  Sendable
{
  private let repository: ExpenseRepositoryProtocol
  private let pageSize: Int

  public init(repository: ExpenseRepositoryProtocol, pageSize: Int = 20) {
    self.repository = repository
    self.pageSize = pageSize
  }

  public func execute(
    counterpartyId: UUID,
    page: Int,
    status: CounterpartyExpenseStatus = .all,
    cursor: String? = nil
  ) async throws -> ExpensePage {
    try await repository.fetchExpenses(
      counterpartyId: counterpartyId,
      page: page,
      limit: pageSize,
      status: status,
      cursor: cursor
    )
  }
}

public protocol FetchNettingSummaryUseCaseProtocol: Sendable {
  func execute(counterpartyId: UUID) async throws -> NettingSummary
}

public final class FetchNettingSummaryUseCase: FetchNettingSummaryUseCaseProtocol, Sendable {
  private let repository: ExpenseRepositoryProtocol

  public init(repository: ExpenseRepositoryProtocol) {
    self.repository = repository
  }

  public func execute(counterpartyId: UUID) async throws -> NettingSummary {
    try await repository.fetchNetting(counterpartyId: counterpartyId)
  }
}

public protocol SubmitBulkSettlementUseCaseProtocol: Sendable {
  func execute(counterpartyId: UUID, evidenceURL: URL, note: String?) async throws
    -> BulkSettlement
}

public final class SubmitBulkSettlementUseCase: SubmitBulkSettlementUseCaseProtocol, Sendable {
  private let repository: ExpenseRepositoryProtocol

  public init(repository: ExpenseRepositoryProtocol) {
    self.repository = repository
  }

  public func execute(
    counterpartyId: UUID,
    evidenceURL: URL,
    note: String?
  ) async throws -> BulkSettlement {
    try await repository.submitBulkSettlement(
      counterpartyId: counterpartyId,
      evidenceURL: evidenceURL,
      note: note
    )
  }
}

public protocol ApproveBulkSettlementUseCaseProtocol: Sendable {
  func execute(id: UUID) async throws -> BulkSettlement
}

public final class ApproveBulkSettlementUseCase: ApproveBulkSettlementUseCaseProtocol, Sendable {
  private let repository: ExpenseRepositoryProtocol

  public init(repository: ExpenseRepositoryProtocol) {
    self.repository = repository
  }

  public func execute(id: UUID) async throws -> BulkSettlement {
    try await repository.approveBulkSettlement(id: id)
  }
}

public protocol RejectBulkSettlementUseCaseProtocol: Sendable {
  func execute(id: UUID, reason: String?) async throws -> BulkSettlement
}

public final class RejectBulkSettlementUseCase: RejectBulkSettlementUseCaseProtocol, Sendable {
  private let repository: ExpenseRepositoryProtocol

  public init(repository: ExpenseRepositoryProtocol) {
    self.repository = repository
  }

  public func execute(id: UUID, reason: String?) async throws -> BulkSettlement {
    try await repository.rejectBulkSettlement(id: id, reason: reason)
  }
}
