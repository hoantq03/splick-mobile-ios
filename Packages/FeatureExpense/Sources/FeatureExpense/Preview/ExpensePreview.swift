import Foundation
import SwiftUI
import SplickDomain

#if DEBUG

final class MockFetchExpensesUseCase: FetchExpensesUseCaseProtocol, Sendable {
    func execute(groupId: UUID?, page: Int) async throws -> [Expense] {
        try await Task.sleep(for: .milliseconds(500))
        return PreviewData.sampleExpenses
    }
}

final class MockFetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol, Sendable {
    func execute(groupId: UUID?) async throws -> [DebtSummary] {
        PreviewData.sampleDebts
    }
}

final class MockCreateExpenseUseCase: CreateExpenseUseCaseProtocol, Sendable {
    func execute(_ request: CreateExpenseRequest) async throws -> Expense {
        try await Task.sleep(for: .seconds(1))
        return PreviewData.sampleExpense
    }
}

#Preview("Expense List") {
    ExpenseListView(
        viewModel: ExpenseListViewModel(
            fetchExpensesUseCase: MockFetchExpensesUseCase(),
            fetchDebtSummaryUseCase: MockFetchDebtSummaryUseCase()
        )
    )
}

#Preview("Create Expense") {
    CreateExpenseView(
        viewModel: CreateExpenseViewModel(
            createExpenseUseCase: MockCreateExpenseUseCase()
        )
    )
}

#endif
