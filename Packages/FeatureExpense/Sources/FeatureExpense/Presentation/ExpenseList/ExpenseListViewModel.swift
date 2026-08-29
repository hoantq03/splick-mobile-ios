import Foundation
import SwiftUI
import Common
import Localization
import SplickDomain
import Storage

@MainActor
public final class ExpenseListViewModel: ObservableObject {
    @Published var expenses: [Expense] = [] {
        didSet { reconcileDisplayedExpenses() }
    }
    @Published var debts: [DebtSummary] = []
    @Published var monthlySummary: MonthlyExpenseSummary?
    @Published var state: LoadingState<[Expense]> = .idle
    @Published private(set) var isRefreshing = false
    @Published var showCreateExpense = false
    @Published var filters = ExpenseListFilters()
    @Published private(set) var displayedExpenses: [Expense] = []

    private static let listFilterAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Skip silent reloads that happen within this window (tab remount / duplicate triggers).
    private static let freshLoadInterval: TimeInterval = 30

    private let fetchExpensesUseCase: FetchExpensesUseCaseProtocol
    private let fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol
    private let fetchMonthlySummaryUseCase: FetchMonthlySummaryUseCaseProtocol?
    private let languageService: LanguageService
    private let onBadgeCountsChanged: (() async -> Void)?
    private let onDataLoaded: (([DebtSummary], [Expense], UUID?) async -> Void)?
    private let groupId: UUID?
    private(set) var currentUserId: UUID?
    private var nextCursor: String?
    private var hasMorePages = true
    /// Single in-flight load for both cold load and pull-to-refresh.
    private var inFlightLoadTask: Task<Void, Never>?
    private var lastSuccessfulLoadAt: Date?

    private struct ExpenseListCachePayload: Codable {
        let expenses: [Expense]
        let debts: [DebtSummary]
    }

    public init(
        fetchExpensesUseCase: FetchExpensesUseCaseProtocol,
        fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol,
        fetchMonthlySummaryUseCase: FetchMonthlySummaryUseCaseProtocol? = nil,
        languageService: LanguageService,
        groupId: UUID? = nil,
        currentUserId: UUID? = nil,
        onBadgeCountsChanged: (() async -> Void)? = nil,
        onDataLoaded: (([DebtSummary], [Expense], UUID?) async -> Void)? = nil
    ) {
        self.fetchExpensesUseCase = fetchExpensesUseCase
        self.fetchDebtSummaryUseCase = fetchDebtSummaryUseCase
        self.fetchMonthlySummaryUseCase = fetchMonthlySummaryUseCase
        self.languageService = languageService
        self.onBadgeCountsChanged = onBadgeCountsChanged
        self.onDataLoaded = onDataLoaded
        self.groupId = groupId
        self.currentUserId = currentUserId
    }

    /// Reactive list used by the UI — recomputes whenever `expenses` or `filters` change.
    var filteredExpenses: [Expense] {
        displayedExpenses
    }

    var filteredDebts: [DebtSummary] {
        debts.filter(matchesDebtFilters)
    }

    var filterSignature: String {
        var parts = [filters.captionQuery, filters.debtStatus.rawValue]
        if let userId = filters.selectedUser?.id { parts.append(userId.uuidString) }
        if let from = filters.dateFrom { parts.append("from-\(from.timeIntervalSince1970)") }
        if let to = filters.dateTo { parts.append("to-\(to.timeIntervalSince1970)") }
        return parts.joined(separator: "|")
    }

    func updateCurrentUserId(_ id: UUID?) {
        guard currentUserId != id else { return }
        currentUserId = id
        reconcileDisplayedExpenses()
    }

    var totalOwed: Decimal {
        filteredDebts.filter(\.isOwed).reduce(Decimal.zero) { $0 + $1.amount }
    }

    var totalOwing: Decimal {
        filteredDebts.filter(\.owes).reduce(Decimal.zero) { $0 + abs($1.amount) }
    }

    var overviewOwedPeopleCount: Int {
        debts.filter(\.isOwed).count
    }

    var overviewOwingPeopleCount: Int {
        debts.filter(\.owes).count
    }

    var overviewTotalOwed: Decimal {
        debts.filter(\.isOwed).reduce(Decimal.zero) { $0 + $1.amount }
    }

    var overviewTotalOwing: Decimal {
        debts.filter(\.owes).reduce(Decimal.zero) { $0 + abs($1.amount) }
    }

    var overviewOweUnpaidTotal: Decimal { overviewSnapshot.oweUnpaidTotal }
    var overviewOweUnpaidCount: Int { overviewSnapshot.oweUnpaidCount }
    var overviewOwePaidTotal: Decimal { overviewSnapshot.owePaidTotal }
    var overviewOwePaidCount: Int { overviewSnapshot.owePaidCount }
    var overviewOwedUnpaidTotal: Decimal { overviewSnapshot.owedUnpaidTotal }
    var overviewOwedUnpaidCount: Int { overviewSnapshot.owedUnpaidCount }
    var overviewOwedPaidTotal: Decimal { overviewSnapshot.owedPaidTotal }
    var overviewOwedPaidCount: Int { overviewSnapshot.owedPaidCount }

    var todayOweUnpaidTotal: Decimal { todaySnapshot.oweUnpaidTotal }
    var todayOwedUnpaidTotal: Decimal { todaySnapshot.owedUnpaidTotal }
    var todayNetUnpaid: Decimal { todayOwedUnpaidTotal - todayOweUnpaidTotal }

    private var overviewSnapshot = ExpenseOverviewSnapshot.empty
    private var todaySnapshot = ExpenseOverviewSnapshot.empty

    var currentMonthReceived: Decimal {
        monthlySummary?.currentMonth.totalSettledReceived ?? .zero
    }

    var currentMonthPaid: Decimal {
        monthlySummary?.currentMonth.totalSettledPaid ?? .zero
    }

    var chartData: [MonthData] {
        monthlySummary?.months ?? []
    }

    var monthlySummaryCurrency: String {
        monthlySummary?.currency ?? "VND"
    }

    private func overviewTotal(for state: ExpenseUserDebtState) -> Decimal {
        overviewSnapshot.total(for: state)
    }

    private func overviewCount(for state: ExpenseUserDebtState) -> Int {
        overviewSnapshot.count(for: state)
    }

    /// Expenses that feed overview charts — same date/caption/friend scope as history,
    /// but without debt-status so all chart segments stay visible for selection.
    private var overviewScopedExpenses: [Expense] {
        expenses.filter { expense in
            matchesCaption(expense)
                && matchesUser(expense)
                && matchesDateRange(expense)
        }
    }

    /// Loads expenses when idle/failed, or when data is older than the freshness window.
    public func loadIfNeeded() async {
        await loadDiskCacheIfNeeded()
        if case .loaded = state,
           let lastSuccessfulLoadAt,
           Date().timeIntervalSince(lastSuccessfulLoadAt) < Self.freshLoadInterval {
            return
        }
        await load(isPullToRefresh: false)
    }

    public func load(isPullToRefresh: Bool = false) async {
        if let existing = inFlightLoadTask {
            await existing.value
            return
        }

        if !isPullToRefresh,
           case .loaded = state,
           let lastSuccessfulLoadAt,
           Date().timeIntervalSince(lastSuccessfulLoadAt) < Self.freshLoadInterval {
            return
        }

        let task = Task { @MainActor in
            if isPullToRefresh {
                isRefreshing = true
            } else if case .loaded = state, !expenses.isEmpty {
                // Keep showing existing rows while refreshing in the background.
            } else {
                state = .loading
            }
            defer {
                if isPullToRefresh {
                    isRefreshing = false
                }
            }
            await performLoad(isPullToRefresh: isPullToRefresh)
        }
        inFlightLoadTask = task
        await task.value
        inFlightLoadTask = nil
    }

    private func performLoad(isPullToRefresh: Bool) async {
        nextCursor = nil
        hasMorePages = true
        Log.info("Loading expenses", category: .expense, metadata: ["pullToRefresh": String(isPullToRefresh)])

        do {
            async let expensesTask = fetchExpensesUseCase.execute(
                groupId: groupId, page: 0, cursor: nil)
            async let debtsTask = fetchDebtSummaryUseCase.execute(groupId: groupId)

            let (fetchedExpenses, fetchedDebts) = try await (expensesTask, debtsTask)
            expenses = fetchedExpenses
            debts = fetchedDebts
            hasMorePages = fetchedExpenses.count >= 20
            if let last = fetchedExpenses.last {
                nextCursor = ExpenseListCursor.encode(createdAt: last.createdAt, expenseId: last.id)
            } else {
                nextCursor = nil
            }

            if let fetchMonthlySummaryUseCase {
                do {
                    monthlySummary = try await fetchMonthlySummaryUseCase.execute(months: 12)
                } catch {
                    Log.warning(
                        "Monthly summary load failed",
                        category: .expense,
                        metadata: ["error": error.localizedDescription]
                    )
                }
            }

            state = .loaded(fetchedExpenses)
            lastSuccessfulLoadAt = Date()
            persistDiskCache()
            Log.info(
                "Loaded expenses",
                category: .expense,
                metadata: [
                    "expenseCount": String(fetchedExpenses.count),
                    "debtCount": String(fetchedDebts.count),
                    "hasMonthlySummary": String(monthlySummary != nil),
                ]
            )
            if isPullToRefresh {
                await onBadgeCountsChanged?()
            }
            await onDataLoaded?(fetchedDebts, fetchedExpenses, currentUserId)
        } catch {
            if !expenses.isEmpty {
                state = .loaded(expenses)
            } else {
                state = .failed(languageService.localizedMessage(for: error))
            }
            Log.error(error, category: .expense)
        }
    }

    private func loadDiskCacheIfNeeded() async {
        guard expenses.isEmpty, let userId = currentUserId else { return }
        let key = Self.cacheKey(userId: userId, groupId: groupId)
        guard let cached = await DiskCache.shared.read(ExpenseListCachePayload.self, key: key) else {
            return
        }
        expenses = cached.expenses
        debts = cached.debts
        if let last = cached.expenses.last {
            nextCursor = ExpenseListCursor.encode(createdAt: last.createdAt, expenseId: last.id)
            hasMorePages = cached.expenses.count >= 20
        }
        state = .loaded(cached.expenses)
        Log.info(
            "Loaded expenses from disk cache",
            category: .expense,
            metadata: ["count": String(cached.expenses.count)]
        )
    }

    private func persistDiskCache() {
        guard let userId = currentUserId else { return }
        let payload = ExpenseListCachePayload(expenses: expenses, debts: debts)
        let key = Self.cacheKey(userId: userId, groupId: groupId)
        Task {
            await DiskCache.shared.write(payload, key: key)
        }
    }

    private static func cacheKey(userId: UUID, groupId: UUID?) -> String {
        if let groupId {
            return "expenses.list.\(userId.uuidString).\(groupId.uuidString)"
        }
        return "expenses.list.\(userId.uuidString)"
    }

    func loadMore() async {
        guard hasMorePages, let cursor = nextCursor else { return }
        do {
            let newExpenses = try await fetchExpensesUseCase.execute(
                groupId: groupId, page: 0, cursor: cursor)
            expenses.append(contentsOf: newExpenses)
            hasMorePages = newExpenses.count >= 20
            if let last = newExpenses.last {
                nextCursor = ExpenseListCursor.encode(createdAt: last.createdAt, expenseId: last.id)
            } else {
                nextCursor = nil
                hasMorePages = false
            }
            persistDiskCache()
            state = .loaded(expenses)
        } catch {
            Log.error(error, category: .expense)
        }
    }

    func setCaptionQuery(_ query: String) {
        mutateFilters { $0.captionQuery = query }
    }

    func setDebtStatus(_ status: ExpenseDebtFilter) {
        mutateFilters { $0.debtStatus = status }
    }

    func applyOverviewDebtFilter(_ status: ExpenseDebtFilter) {
        withAnimation(Self.listFilterAnimation) {
            mutateFilters {
                if $0.debtStatus == status {
                    $0.debtStatus = .all
                } else {
                    $0.debtStatus = status
                    $0.selectedUser = nil
                }
            }
        }
    }

    func setSelectedUser(_ user: UserSummary?) {
        mutateFilters { $0.selectedUser = user }
    }

    func setDateFrom(_ date: Date?) {
        mutateFilters { $0.dateFrom = date.map { Calendar.current.startOfDay(for: $0) } }
    }

    func setDateTo(_ date: Date?) {
        mutateFilters { $0.dateTo = date.map { Calendar.current.startOfDay(for: $0) } }
    }

    func setAdvancedExpanded(_ expanded: Bool) {
        mutateFilters { $0.isAdvancedExpanded = expanded }
    }

    func clearAdvancedFilters() {
        mutateFilters {
            $0.debtStatus = .all
            $0.selectedUser = nil
            $0.dateFrom = ExpenseListFilters.defaultMonthStart
            $0.dateTo = nil
        }
    }

    func applyDatePreset(_ preset: ExpenseDatePreset) {
        mutateFilters {
            switch preset {
            case .week:
                $0.dateFrom = ExpenseListFilters.defaultWeekStart
                $0.dateTo = nil
            case .month:
                $0.dateFrom = ExpenseListFilters.defaultMonthStart
                $0.dateTo = nil
            case .all:
                $0.dateFrom = nil
                $0.dateTo = nil
            }
        }
    }

    func clearListFilters() {
        mutateFilters {
            $0.captionQuery = ""
            $0.selectedUser = nil
            $0.dateFrom = ExpenseListFilters.defaultMonthStart
            $0.dateTo = nil
        }
    }

    var filterParticipantUsers: [UserSummary] {
        var seen = Set<UUID>()
        var users: [UserSummary] = []

        for expense in expenses {
            let participants = [expense.paidBy] + expense.splits.map(\.user)
            for user in participants where seen.insert(user.id).inserted {
                users.append(user)
            }
        }

        return users.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func mutateFilters(_ mutation: (inout ExpenseListFilters) -> Void) {
        var next = filters
        mutation(&next)
        filters = next
        reconcileDisplayedExpenses()
    }

    private func reconcileDisplayedExpenses() {
        displayedExpenses = expenses.filter(matchesFilters)
        rebuildOverviewSnapshot()
    }

    private func rebuildOverviewSnapshot() {
        var snapshot = ExpenseOverviewSnapshot.empty
        for expense in overviewScopedExpenses {
            accumulate(expense, into: &snapshot)
        }
        overviewSnapshot = snapshot
        rebuildTodaySnapshot()
    }

    private func rebuildTodaySnapshot() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var snapshot = ExpenseOverviewSnapshot.empty
        for expense in expenses {
            guard calendar.isDate(expense.createdAt, inSameDayAs: today) else { continue }
            guard matchesCaption(expense), matchesUser(expense) else { continue }
            accumulate(expense, into: &snapshot)
        }
        todaySnapshot = snapshot
    }

    private func accumulate(_ expense: Expense, into snapshot: inout ExpenseOverviewSnapshot) {
        let state = expense.userDebtState(userId: currentUserId)
        let amount = expense.userDebtAmount(userId: currentUserId, state: state)
        switch state {
        case .oweUnpaid:
            snapshot.oweUnpaidTotal += amount
            snapshot.oweUnpaidCount += 1
        case .owePaid:
            snapshot.owePaidTotal += amount
            snapshot.owePaidCount += 1
        case .owedUnpaid:
            snapshot.owedUnpaidTotal += amount
            snapshot.owedUnpaidCount += 1
        case .owedPaid:
            snapshot.owedPaidTotal += amount
            snapshot.owedPaidCount += 1
        case .neutral:
            break
        }
    }

    // MARK: - Filtering

    private func matchesFilters(_ expense: Expense) -> Bool {
        guard matchesCaption(expense) else { return false }
        guard matchesDebtStatus(expense) else { return false }
        guard matchesUser(expense) else { return false }
        guard matchesDateRange(expense) else { return false }
        return true
    }

    private func matchesCaption(_ expense: Expense) -> Bool {
        let query = filters.captionQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return expense.description.localizedCaseInsensitiveContains(query)
    }

    private func matchesDebtFilters(_ debt: DebtSummary) -> Bool {
        switch filters.debtStatus {
        case .all:
            break
        case .oweUnpaid, .owePaid:
            guard debt.owes else { return false }
        case .owedUnpaid, .owedPaid:
            guard debt.isOwed else { return false }
        }

        if let user = filters.selectedUser, debt.user.id != user.id {
            return false
        }

        return true
    }

    private func matchesDebtStatus(_ expense: Expense) -> Bool {
        guard let targetState = filters.debtStatus.matchingDebtState else {
            return true
        }
        return expense.userDebtState(userId: currentUserId) == targetState
    }

    private func matchesUser(_ expense: Expense) -> Bool {
        guard let user = filters.selectedUser else { return true }
        if expense.paidBy.id == user.id { return true }
        return expense.splits.contains { $0.user.id == user.id }
    }

    private func matchesDateRange(_ expense: Expense) -> Bool {
        let expenseDay = Calendar.current.startOfDay(for: expense.createdAt)
        if let from = filters.dateFrom, expenseDay < from { return false }
        if let to = filters.dateTo, expenseDay > to { return false }
        return true
    }
}

private struct ExpenseOverviewSnapshot {
    static let empty = ExpenseOverviewSnapshot()

    var oweUnpaidTotal: Decimal = 0
    var oweUnpaidCount: Int = 0
    var owePaidTotal: Decimal = 0
    var owePaidCount: Int = 0
    var owedUnpaidTotal: Decimal = 0
    var owedUnpaidCount: Int = 0
    var owedPaidTotal: Decimal = 0
    var owedPaidCount: Int = 0

    func total(for state: ExpenseUserDebtState) -> Decimal {
        switch state {
        case .oweUnpaid: return oweUnpaidTotal
        case .owePaid: return owePaidTotal
        case .owedUnpaid: return owedUnpaidTotal
        case .owedPaid: return owedPaidTotal
        case .neutral: return 0
        }
    }

    func count(for state: ExpenseUserDebtState) -> Int {
        switch state {
        case .oweUnpaid: return oweUnpaidCount
        case .owePaid: return owePaidCount
        case .owedUnpaid: return owedUnpaidCount
        case .owedPaid: return owedPaidCount
        case .neutral: return 0
        }
    }
}
