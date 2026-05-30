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

final class MockUserSearchUseCase: UserSearchUseCaseProtocol, Sendable {
    func execute(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        let all = [PreviewData.friendUser, PreviewData.friend2]
        let filtered = query.isEmpty
            ? all
            : all.filter {
                $0.displayName.localizedCaseInsensitiveContains(query)
                    || $0.username.localizedCaseInsensitiveContains(query)
            }
        let start = page * limit
        guard start < filtered.count else { return [] }
        return Array(filtered[start..<min(start + limit, filtered.count)])
    }
}

#Preview("Expense List") {
    ExpenseListView(
        viewModel: ExpenseListViewModel(
            fetchExpensesUseCase: MockFetchExpensesUseCase(),
            fetchDebtSummaryUseCase: MockFetchDebtSummaryUseCase(),
            currentUserId: PreviewData.currentUser.id
        ),
        userSearchUseCase: MockUserSearchUseCase(),
        currentUserId: PreviewData.currentUser.id
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
