import Foundation
import Networking
import SplickDomain

public final class ExpenseRepository: ExpenseRepositoryProtocol, Sendable {
  private let apiClient: APIClientProtocol

  public init(apiClient: APIClientProtocol) {
    self.apiClient = apiClient
  }

  public func fetchExpenses(groupId: UUID?, page: Int, limit: Int) async throws -> [Expense] {
    let dtos: [ExpenseResponseDTO] = try await apiClient.request(
      ExpenseEndpoint.list(groupId: groupId, page: page, limit: limit)
    )
    return dtos.map(ExpenseMapper.toExpense)
  }

  public func fetchExpense(id: UUID) async throws -> Expense {
    let dto: ExpenseResponseDTO = try await apiClient.request(ExpenseEndpoint.detail(id: id))
    return ExpenseMapper.toExpense(dto)
  }

  public func createExpense(_ request: CreateExpenseRequest) async throws -> Expense {
    let requestDTO = ExpenseMapper.toRequestDTO(request)
    let dto: ExpenseResponseDTO = try await apiClient.request(ExpenseEndpoint.create(requestDTO))
    return ExpenseMapper.toExpense(dto)
  }

  public func settleExpense(expenseId: UUID, splitId: UUID) async throws {
    let dto = SettleExpenseRequestDTO(splitId: splitId)
    try await apiClient.request(ExpenseEndpoint.settle(expenseId: expenseId, dto))
  }

  public func fetchDebtSummary(groupId: UUID?) async throws -> [DebtSummary] {
    let page: DebtSummaryPageDTO = try await apiClient.request(
      ExpenseEndpoint.debtSummary(groupId: groupId)
    )
    return page.content.map(ExpenseMapper.toDebtSummary)
  }

  public func fetchMonthlySummary(months: Int) async throws -> MonthlyExpenseSummary {
    let dto: MonthlyExpenseSummaryDTO = try await apiClient.request(
      ExpenseEndpoint.monthlySummary(months: months)
    )
    return ExpenseMapper.toMonthlySummary(dto)
  }

  public func fetchExpenses(
    counterpartyId: UUID,
    page: Int,
    limit: Int,
    status: CounterpartyExpenseStatus
  ) async throws -> ExpensePage {
    let response: ExpensePageResponseDTO<ExpenseResponseDTO> = try await apiClient.request(
      ExpenseEndpoint.withCounterparty(
        id: counterpartyId,
        page: page,
        limit: limit,
        status: status
      )
    )
    return ExpensePage(
      expenses: response.content.map(ExpenseMapper.toExpense),
      page: response.page,
      totalPages: response.totalPages,
      totalItems: response.clampedTotalElements,
      hasNext: response.hasNext
    )
  }

  public func fetchNetting(counterpartyId: UUID) async throws -> NettingSummary {
    let dto: NettingSummaryDTO = try await apiClient.request(
      ExpenseEndpoint.netting(counterpartyId: counterpartyId)
    )
    return try ExpenseMapper.toNettingSummary(dto)
  }

  public func submitBulkSettlement(
    counterpartyId: UUID,
    evidenceURL: URL,
    note: String?
  ) async throws -> BulkSettlement {
    let dto: BulkSettlementDTO = try await apiClient.request(
      ExpenseEndpoint.submitBulkSettlement(
        counterpartyId: counterpartyId,
        SubmitBulkSettlementRequestDTO(
          evidenceUrl: evidenceURL.absoluteString,
          note: note
        )
      )
    )
    return try ExpenseMapper.toBulkSettlement(dto)
  }

  public func approveBulkSettlement(id: UUID) async throws -> BulkSettlement {
    let dto: BulkSettlementDTO = try await apiClient.request(
      ExpenseEndpoint.approveBulkSettlement(id: id)
    )
    return try ExpenseMapper.toBulkSettlement(dto)
  }

  public func rejectBulkSettlement(id: UUID, reason: String?) async throws -> BulkSettlement {
    let dto: BulkSettlementDTO = try await apiClient.request(
      ExpenseEndpoint.rejectBulkSettlement(
        id: id,
        RejectBulkSettlementRequestDTO(reason: reason)
      )
    )
    return try ExpenseMapper.toBulkSettlement(dto)
  }
}
