import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class ExpenseListViewModel: ObservableObject {
    @Published var expenses: [Expense] = [] {
        didSet {
            reconcileDisplayedExpenses()
            objectWillChange.send()
        }
    }
    @Published var debts: [DebtSummary] = []
    @Published var state: LoadingState<[Expense]> = .idle
    @Published private(set) var isRefreshing = false
    @Published var showCreateExpense = false
    @Published var filters = ExpenseListFilters()
    @Published private(set) var displayedExpenses: [Expense] = []

    private static let listFilterAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86)

    private let fetchExpensesUseCase: FetchExpensesUseCaseProtocol
    private let fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol
    private let onBadgeCountsChanged: (() async -> Void)?
    private let groupId: UUID?
    private(set) var currentUserId: UUID?
    private var currentPage = 0

    public init(
        fetchExpensesUseCase: FetchExpensesUseCaseProtocol,
        fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol,
        groupId: UUID? = nil,
        currentUserId: UUID? = nil,
        onBadgeCountsChanged: (() async -> Void)? = nil
    ) {
        self.fetchExpensesUseCase = fetchExpensesUseCase
        self.fetchDebtSummaryUseCase = fetchDebtSummaryUseCase
        self.onBadgeCountsChanged = onBadgeCountsChanged
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
        objectWillChange.send()
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

    func load(isPullToRefresh: Bool = false) async {
        if isPullToRefresh {
            guard !isRefreshing else { return }
            isRefreshing = true
        } else {
            state = .loading
        }

        currentPage = 0
        Log.info("Loading expenses", category: .expense, metadata: ["pullToRefresh": String(isPullToRefresh)])

        do {
            async let expensesTask = fetchExpensesUseCase.execute(groupId: groupId, page: 0)
            async let debtsTask = fetchDebtSummaryUseCase.execute(groupId: groupId)

            let (fetchedExpenses, fetchedDebts) = try await (expensesTask, debtsTask)
            expenses = fetchedExpenses
            debts = fetchedDebts
            state = .loaded(fetchedExpenses)
            objectWillChange.send()
            Log.info(
                "Loaded expenses",
                category: .expense,
                metadata: ["expenseCount": String(fetchedExpenses.count), "debtCount": String(fetchedDebts.count)]
            )
            await onBadgeCountsChanged?()
        } catch {
            if isPullToRefresh, !expenses.isEmpty {
                state = .loaded(expenses)
            } else {
                state = .failed(error.localizedDescription)
            }
            Log.error(error, category: .expense)
        }

        isRefreshing = false
    }

    func loadMore() async {
        currentPage += 1
        do {
            let newExpenses = try await fetchExpensesUseCase.execute(groupId: groupId, page: currentPage)
            expenses.append(contentsOf: newExpenses)
            state = .loaded(expenses)
            objectWillChange.send()
        } catch {
            currentPage -= 1
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
            $0.dateFrom = ExpenseListFilters.defaultWeekStart
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
                $0.dateFrom = Calendar.current.date(
                    byAdding: .day,
                    value: -30,
                    to: Calendar.current.startOfDay(for: .now)
                )
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
            $0.dateFrom = ExpenseListFilters.defaultWeekStart
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
        objectWillChange.send()
    }

    private func reconcileDisplayedExpenses() {
        displayedExpenses = expenses.filter(matchesFilters)
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
        case .all: break
        case .owe: guard debt.owes else { return false }
        case .owed: guard debt.isOwed else { return false }
        }

        if let user = filters.selectedUser, debt.user.id != user.id {
            return false
        }

        return true
    }

    private func matchesDebtStatus(_ expense: Expense) -> Bool {
        switch filters.debtStatus {
        case .all:
            return true
        case .owe:
            return expenseMatchesOweFilter(expense)
        case .owed:
            return expenseMatchesOwedFilter(expense)
        }
    }

    /// Align list with debt summary: expense involves a user in the filtered debt set.
    private func expenseMatchesOweFilter(_ expense: Expense) -> Bool {
        if let userId = currentUserId {
            return expense.splits.contains { $0.user.id == userId && !$0.isPaid }
        }

        let owingUserIds = Set(debts.filter(\.owes).map(\.user.id))
        guard !owingUserIds.isEmpty else {
            return expense.splits.contains { !$0.isPaid }
        }
        return expense.splits.contains { !$0.isPaid && owingUserIds.contains($0.user.id) }
    }

    private func expenseMatchesOwedFilter(_ expense: Expense) -> Bool {
        if let userId = currentUserId {
            guard expense.paidBy.id == userId else { return false }
            return expense.splits.contains { $0.user.id != userId && !$0.isPaid }
        }

        let owedUserIds = Set(debts.filter(\.isOwed).map(\.user.id))
        guard !owedUserIds.isEmpty else { return false }
        return expense.splits.contains { !$0.isPaid && owedUserIds.contains($0.user.id) }
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
