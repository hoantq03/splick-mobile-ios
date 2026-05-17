import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class ExpenseListViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var debts: [DebtSummary] = []
    @Published var state: LoadingState<[Expense]> = .idle
    @Published var showCreateExpense = false

    private let fetchExpensesUseCase: FetchExpensesUseCaseProtocol
    private let fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol
    private let groupId: UUID?
    private var currentPage = 0

    public init(
        fetchExpensesUseCase: FetchExpensesUseCaseProtocol,
        fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol,
        groupId: UUID? = nil
    ) {
        self.fetchExpensesUseCase = fetchExpensesUseCase
        self.fetchDebtSummaryUseCase = fetchDebtSummaryUseCase
        self.groupId = groupId
    }

    func load() async {
        state = .loading
        currentPage = 0

        do {
            async let expensesTask = fetchExpensesUseCase.execute(groupId: groupId, page: 0)
            async let debtsTask = fetchDebtSummaryUseCase.execute(groupId: groupId)

            let (fetchedExpenses, fetchedDebts) = try await (expensesTask, debtsTask)
            expenses = fetchedExpenses
            debts = fetchedDebts
            state = .loaded(fetchedExpenses)
        } catch {
            state = .failed(error.localizedDescription)
            Log.error(error, category: .expense)
        }
    }

    func loadMore() async {
        currentPage += 1
        do {
            let newExpenses = try await fetchExpensesUseCase.execute(groupId: groupId, page: currentPage)
            expenses.append(contentsOf: newExpenses)
            state = .loaded(expenses)
        } catch {
            currentPage -= 1
            Log.error(error, category: .expense)
        }
    }

    var totalOwed: Decimal {
        debts.filter(\.isOwed).reduce(Decimal.zero) { $0 + $1.amount }
    }

    var totalOwing: Decimal {
        debts.filter(\.owes).reduce(Decimal.zero) { $0 + abs($1.amount) }
    }
}
