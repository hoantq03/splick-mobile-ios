import Foundation
import Localization
import SplickDomain
import Storage
import XCTest

@testable import FeatureExpense

@MainActor
final class ExpenseTabCacheFirstLoadTests: XCTestCase {
  func test_listLoadIfNeeded_fetchesOnceThenSkipsUntilPullToRefresh() async {
    let expenses = StubFetchExpensesUseCase(expenses: [makeExpense()])
    let debts = StubFetchDebtSummaryUseCase(debts: [makeDebt()])
    let viewModel = ExpenseListViewModel(
      fetchExpensesUseCase: expenses,
      fetchDebtSummaryUseCase: debts,
      languageService: makeLanguageService()
    )

    await viewModel.loadIfNeeded()
    await viewModel.loadIfNeeded()

    var expenseCalls = await expenses.callCount
    var debtCalls = await debts.callCount
    XCTAssertEqual(expenseCalls, 1)
    XCTAssertEqual(debtCalls, 1)
    guard case .loaded = viewModel.state else {
      return XCTFail("Expected loaded snapshot after first fetch")
    }

    await viewModel.load(isPullToRefresh: true)

    expenseCalls = await expenses.callCount
    debtCalls = await debts.callCount
    XCTAssertEqual(expenseCalls, 2)
    XCTAssertEqual(debtCalls, 2)
  }

  func test_listSoftSync_skipsWhenNeverOpened() async {
    let expenses = StubFetchExpensesUseCase(expenses: [makeExpense()])
    let debts = StubFetchDebtSummaryUseCase(debts: [])
    let viewModel = ExpenseListViewModel(
      fetchExpensesUseCase: expenses,
      fetchDebtSummaryUseCase: debts,
      languageService: makeLanguageService()
    )

    await viewModel.softSyncDirectory()

    let expenseCalls = await expenses.callCount
    let debtCalls = await debts.callCount
    XCTAssertEqual(expenseCalls, 0)
    XCTAssertEqual(debtCalls, 0)
  }

  func test_overviewLoadIfNeeded_fetchesOnceThenSkipsUntilPullToRefresh() async {
    let overview = StubFetchOverviewUseCase(overview: makeOverview())
    let analytics = StubFetchAnalyticsUseCase()
    let groups = StubFetchGroupsUseCase()
    let viewModel = ExpenseOverviewViewModel(
      fetchOverviewUseCase: overview,
      fetchAnalyticsUseCase: analytics,
      fetchGroupsUseCase: groups,
      languageService: makeLanguageService()
    )

    await viewModel.loadIfNeeded()
    await viewModel.loadIfNeeded()

    var overviewCalls = await overview.callCount
    var analyticsCalls = await analytics.callCount
    var groupCalls = await groups.callCount
    XCTAssertEqual(overviewCalls, 1)
    XCTAssertEqual(analyticsCalls, 1)
    XCTAssertEqual(groupCalls, 1)

    await viewModel.load(isPullToRefresh: true)

    overviewCalls = await overview.callCount
    analyticsCalls = await analytics.callCount
    groupCalls = await groups.callCount
    XCTAssertEqual(overviewCalls, 2)
    XCTAssertEqual(analyticsCalls, 2)
    XCTAssertEqual(groupCalls, 2)
  }

  func test_overviewSoftSync_skipsWhenNeverOpened() async {
    let overview = StubFetchOverviewUseCase(overview: makeOverview())
    let viewModel = ExpenseOverviewViewModel(
      fetchOverviewUseCase: overview,
      fetchAnalyticsUseCase: StubFetchAnalyticsUseCase(),
      fetchGroupsUseCase: StubFetchGroupsUseCase(),
      languageService: makeLanguageService()
    )

    await viewModel.softSync()

    let overviewCalls = await overview.callCount
    XCTAssertEqual(overviewCalls, 0)
  }

  func test_friendsLoadIfNeeded_fetchesOnceThenSkipsUntilPullToRefresh() async {
    let debts = StubFetchDebtSummaryUseCase(debts: [makeDebt()])
    let viewModel = ExpenseFriendListViewModel(
      fetchDebtSummaryUseCase: debts,
      languageService: makeLanguageService()
    )

    await viewModel.loadIfNeeded()
    await viewModel.loadIfNeeded()

    var debtCalls = await debts.callCount
    XCTAssertEqual(debtCalls, 1)

    await viewModel.load(isPullToRefresh: true)

    debtCalls = await debts.callCount
    XCTAssertEqual(debtCalls, 2)
  }

  private func makeLanguageService() -> LanguageService {
    let suite = "ExpenseTabCacheFirstLoadTests.\(UUID().uuidString)"
    return LanguageService(
      userDefaults: UserDefaultsService(defaults: UserDefaults(suiteName: suite)!)
    )
  }

  private func makeUser() -> UserSummary {
    UserSummary(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      username: "me",
      displayName: "Me",
      avatarURL: nil
    )
  }

  private func makeExpense() -> Expense {
    Expense(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
      description: "Lunch",
      totalAmount: 100_000,
      paidBy: makeUser()
    )
  }

  private func makeDebt() -> DebtSummary {
    DebtSummary(user: makeUser(), amount: 50_000, currency: "VND")
  }

  private func makeOverview() -> ExpenseOverview {
    ExpenseOverview(
      balance: ExpenseBalanceSection(
        youOwe: 0,
        owedToYou: 0,
        netBalance: 0,
        currency: "VND",
        topBalances: []
      ),
      needsAttention: ExpenseNeedsAttentionSection(
        pendingPaymentRequestCount: 0,
        expensesNeedingConfirmationCount: 0,
        outstandingSettlementCount: 0,
        totalActionItems: 0,
        items: []
      ),
      recentExpenses: [],
      totalSpending: ExpenseTotalSpendingSection(
        currentPeriodTotal: 0,
        previousPeriodTotal: 0,
        percentageChange: 0,
        currency: "VND"
      )
    )
  }
}

private actor StubFetchExpensesUseCase: FetchExpensesUseCaseProtocol {
  private let expenses: [Expense]
  private(set) var callCount = 0

  init(expenses: [Expense]) {
    self.expenses = expenses
  }

  func execute(groupId: UUID?, page: Int, cursor: String?) async throws -> [Expense] {
    callCount += 1
    return expenses
  }
}

private actor StubFetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol {
  private let debts: [DebtSummary]
  private(set) var callCount = 0

  init(debts: [DebtSummary]) {
    self.debts = debts
  }

  func execute(groupId: UUID?) async throws -> [DebtSummary] {
    callCount += 1
    return debts
  }
}

private actor StubFetchOverviewUseCase: FetchExpenseOverviewUseCaseProtocol {
  private let overview: ExpenseOverview
  private(set) var callCount = 0

  init(overview: ExpenseOverview) {
    self.overview = overview
  }

  func execute() async throws -> ExpenseOverview {
    callCount += 1
    return overview
  }
}

private actor StubFetchAnalyticsUseCase: FetchSpendingAnalyticsUseCaseProtocol {
  private(set) var callCount = 0

  func execute(period: SpendingAnalyticsPeriod, months: Int) async throws -> SpendingAnalytics {
    callCount += 1
    return SpendingAnalytics(trend: [], categories: [], currency: "VND")
  }
}

private actor StubFetchGroupsUseCase: FetchGroupExpenseSummaryUseCaseProtocol {
  private(set) var callCount = 0

  func execute() async throws -> GroupExpenseSummary {
    callCount += 1
    return GroupExpenseSummary(groups: [])
  }
}
