import Foundation
import SplickDomain

public protocol FetchMonthlySummaryUseCaseProtocol: Sendable {
  func execute(months: Int) async throws -> MonthlyExpenseSummary
}

public final class FetchMonthlySummaryUseCase: FetchMonthlySummaryUseCaseProtocol, Sendable {
  private let repository: ExpenseRepositoryProtocol

  public init(repository: ExpenseRepositoryProtocol) {
    self.repository = repository
  }

  public func execute(months: Int = 12) async throws -> MonthlyExpenseSummary {
    try await repository.fetchMonthlySummary(months: months)
  }
}
