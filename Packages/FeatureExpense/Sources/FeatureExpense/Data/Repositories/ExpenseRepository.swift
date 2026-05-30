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
}
