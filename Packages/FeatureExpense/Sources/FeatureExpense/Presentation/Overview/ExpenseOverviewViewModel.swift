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

  /// Fetches only when this screen has no snapshot yet. Tab re-entry keeps stale data.
  func loadIfNeeded() async {
    if hasCachedSnapshot { return }
    if let inFlightLoadTask {
      await inFlightLoadTask.value
      if hasCachedSnapshot { return }
    }
    await load()
  }

  /// Quiet refresh after a local mutation. Skips if overview was never opened.
  func softSync() async {
    guard hasCachedSnapshot || inFlightLoadTask != nil else { return }
    await load(isPullToRefresh: false, force: true)
  }

  func load(isPullToRefresh: Bool = false, force: Bool = false) async {
    if let inFlightLoadTask {
      await inFlightLoadTask.value
      if !force && !isPullToRefresh { return }
    }
    let task = Task { await performLoad(isPullToRefresh: isPullToRefresh, force: force) }
    inFlightLoadTask = task
    await task.value
    inFlightLoadTask = nil
  }

  private func performLoad(isPullToRefresh: Bool, force: Bool = false) async {
    if !isPullToRefresh, !force, overview == nil {
      state = .loading
    }
    do {
      let result = try await fetchOverviewUseCase.execute()
      overview = result
      state = .loaded(result)
      await loadSecondary()
    } catch is CancellationError {
      // Leave prior loaded/idle state; never stick on .loading after cancel.
      if overview == nil, case .loading = state {
        state = .idle
      }
      return
    } catch {
      if overview == nil {
        state = .failed(languageService.localizedMessage(for: error))
      } else if case .loading = state {
        state = .loaded(overview!)
      }
    }
  }

  private func loadSecondary() async {
    if analytics == nil {
      analyticsState = .loading
    }
    if groups.isEmpty {
      groupsState = .loading
    }
    async let analyticsTask = fetchAnalyticsUseCase.execute(period: .month, months: 3)
    async let groupsTask = fetchGroupsUseCase.execute()
    do {
      let analyticsResult = try await analyticsTask
      analytics = analyticsResult
      analyticsState = .loaded(analyticsResult)
    } catch {
      if analytics == nil {
        analyticsState = .failed(languageService.localizedMessage(for: error))
      }
    }
    do {
      let groupsResult = try await groupsTask
      groups = groupsResult.groups
      groupsState = .loaded(groupsResult.groups)
    } catch {
      if groups.isEmpty {
        groupsState = .failed(languageService.localizedMessage(for: error))
      }
    }
  }

  private var hasCachedSnapshot: Bool {
    if case .loaded = state { return true }
    return overview != nil
  }
}
