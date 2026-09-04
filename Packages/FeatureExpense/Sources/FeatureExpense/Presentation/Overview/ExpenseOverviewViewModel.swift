import Foundation
import SwiftUI
import Common
import Localization
import SplickDomain

@MainActor
public final class ExpenseOverviewViewModel: ObservableObject {
  @Published private(set) var overview: ExpenseOverview?
  @Published private(set) var analytics: SpendingAnalytics?
  @Published private(set) var groups: [GroupExpenseItem] = []
  @Published private(set) var state: LoadingState<ExpenseOverview> = .idle
  @Published private(set) var analyticsState: LoadingState<SpendingAnalytics> = .idle
  @Published private(set) var groupsState: LoadingState<[GroupExpenseItem]> = .idle

  private let fetchOverviewUseCase: FetchExpenseOverviewUseCaseProtocol
  private let fetchAnalyticsUseCase: FetchSpendingAnalyticsUseCaseProtocol
  private let fetchGroupsUseCase: FetchGroupExpenseSummaryUseCaseProtocol
  private let languageService: LanguageService
  private var inFlightLoadTask: Task<Void, Never>?

  public init(
    fetchOverviewUseCase: FetchExpenseOverviewUseCaseProtocol,
    fetchAnalyticsUseCase: FetchSpendingAnalyticsUseCaseProtocol,
    fetchGroupsUseCase: FetchGroupExpenseSummaryUseCaseProtocol,
    languageService: LanguageService
  ) {
    self.fetchOverviewUseCase = fetchOverviewUseCase
    self.fetchAnalyticsUseCase = fetchAnalyticsUseCase
    self.fetchGroupsUseCase = fetchGroupsUseCase
    self.languageService = languageService
  }

  func loadIfNeeded() async {
    if case .loaded = state { return }
    await load()
  }

  func load(isPullToRefresh: Bool = false) async {
    if let inFlightLoadTask {
      await inFlightLoadTask.value
      return
    }
    let task = Task { await performLoad(isPullToRefresh: isPullToRefresh) }
    inFlightLoadTask = task
    await task.value
    inFlightLoadTask = nil
  }

  private func performLoad(isPullToRefresh: Bool) async {
    if !isPullToRefresh, overview == nil {
      state = .loading
    }
    do {
      let result = try await fetchOverviewUseCase.execute()
      overview = result
      state = .loaded(result)
      await loadSecondary()
    } catch is CancellationError {
      return
    } catch {
      if overview == nil {
        state = .failed(languageService.localizedMessage(for: error))
      }
    }
  }

  private func loadSecondary() async {
    analyticsState = analytics == nil ? .loading : analyticsState
    groupsState = groups.isEmpty ? .loading : groupsState
    async let analyticsTask = fetchAnalyticsUseCase.execute(period: .month, months: 3)
    async let groupsTask = fetchGroupsUseCase.execute()
    do {
      let analyticsResult = try await analyticsTask
      analytics = analyticsResult
      analyticsState = .loaded(analyticsResult)
    } catch {
      analyticsState = .failed(languageService.localizedMessage(for: error))
    }
    do {
      let groupsResult = try await groupsTask
      groups = groupsResult.groups
      groupsState = .loaded(groupsResult.groups)
    } catch {
      groupsState = .failed(languageService.localizedMessage(for: error))
    }
  }
}
