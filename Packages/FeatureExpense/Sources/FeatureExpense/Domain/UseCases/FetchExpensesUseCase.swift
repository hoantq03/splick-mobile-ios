import Foundation
import SplickDomain

public protocol FetchExpensesUseCaseProtocol: Sendable {
    func execute(groupId: UUID?, page: Int) async throws -> [Expense]
}

public final class FetchExpensesUseCase: FetchExpensesUseCaseProtocol, Sendable {
    private let repository: ExpenseRepositoryProtocol
    private let pageSize: Int

    public init(repository: ExpenseRepositoryProtocol, pageSize: Int = 20) {
        self.repository = repository
        self.pageSize = pageSize
    }

    public func execute(groupId: UUID?, page: Int) async throws -> [Expense] {
        try await repository.fetchExpenses(groupId: groupId, page: page, limit: pageSize)
    }
}
