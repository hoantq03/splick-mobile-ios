import Foundation
import SplickDomain

public protocol FetchExpenseOverviewUseCaseProtocol: Sendable {
  func execute() async throws -> ExpenseOverview
}

public final class FetchExpenseOverviewUseCase: FetchExpenseOverviewUseCaseProtocol, Sendable {
  private let repository: ExpenseRepositoryProtocol

  public init(repository: ExpenseRepositoryProtocol) {
    self.repository = repository
  }

  public func execute() async throws -> ExpenseOverview {
    try await repository.fetchOverview()
  }
}

public protocol FetchSpendingAnalyticsUseCaseProtocol: Sendable {
  func execute(period: SpendingAnalyticsPeriod, months: Int) async throws -> SpendingAnalytics
}

public final class FetchSpendingAnalyticsUseCase: FetchSpendingAnalyticsUseCaseProtocol, Sendable {
  private let repository: ExpenseRepositoryProtocol

  public init(repository: ExpenseRepositoryProtocol) {
    self.repository = repository
  }

  public func execute(period: SpendingAnalyticsPeriod = .month, months: Int = 3) async throws
    -> SpendingAnalytics
  {
    try await repository.fetchSpendingAnalytics(period: period, months: months)
  }
}

public protocol FetchGroupExpenseSummaryUseCaseProtocol: Sendable {
  func execute() async throws -> GroupExpenseSummary
}

public final class FetchGroupExpenseSummaryUseCase: FetchGroupExpenseSummaryUseCaseProtocol,
  Sendable
{
  private let repository: ExpenseRepositoryProtocol

  public init(repository: ExpenseRepositoryProtocol) {
    self.repository = repository
  }

  public func execute() async throws -> GroupExpenseSummary {
    try await repository.fetchGroupExpenseSummary()
  }
}
