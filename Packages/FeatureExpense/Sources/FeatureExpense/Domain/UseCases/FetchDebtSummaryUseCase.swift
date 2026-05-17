import Foundation
import SplickDomain

public protocol FetchDebtSummaryUseCaseProtocol: Sendable {
    func execute(groupId: UUID?) async throws -> [DebtSummary]
}

public final class FetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol, Sendable {
    private let repository: ExpenseRepositoryProtocol

    public init(repository: ExpenseRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID?) async throws -> [DebtSummary] {
        try await repository.fetchDebtSummary(groupId: groupId)
    }
}
