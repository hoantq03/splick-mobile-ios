import Foundation
import SwiftUI
import Localization
import Storage
import SplickDomain

#if DEBUG

final class MockFetchExpensesUseCase: FetchExpensesUseCaseProtocol, Sendable {
    func execute(groupId: UUID?, page: Int, cursor: String?) async throws -> [Expense] {
        try await Task.sleep(for: .milliseconds(500))
        return PreviewData.sampleExpenses
    }
}

final class MockFetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol, Sendable {
    func execute(groupId: UUID?) async throws -> [DebtSummary] {
        PreviewData.sampleDebts
    }
}

final class MockFetchMonthlySummaryUseCase: FetchMonthlySummaryUseCaseProtocol, Sendable {
    func execute(months: Int) async throws -> MonthlyExpenseSummary {
        let calendar = Calendar.current
        let now = Date()
        var series: [MonthData] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else {
                continue
            }
            let components = calendar.dateComponents([.year, .month], from: date)
            series.append(
                MonthData(
                    year: components.year ?? 2026,
                    month: components.month ?? 1,
                    totalSettledReceived: Decimal((months - offset) * 150_000),
                    totalSettledPaid: Decimal((months - offset) * 220_000)
                )
            )
        }
        let current = series.last ?? MonthData(
            year: 2026, month: 7, totalSettledReceived: 0, totalSettledPaid: 0
        )
        return MonthlyExpenseSummary(currency: "VND", currentMonth: current, months: series)
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
    let previewLanguageService = LanguageService(userDefaults: UserDefaultsService())
    return ExpenseListView(
        viewModel: ExpenseListViewModel(
            fetchExpensesUseCase: MockFetchExpensesUseCase(),
            fetchDebtSummaryUseCase: MockFetchDebtSummaryUseCase(),
            fetchMonthlySummaryUseCase: MockFetchMonthlySummaryUseCase(),
            languageService: previewLanguageService,
            currentUserId: PreviewData.currentUser.id
        ),
        currentUserId: PreviewData.currentUser.id
    )
    .environmentObject(previewLanguageService)
}

#Preview("Create Expense") {
    let previewLanguageService = LanguageService(userDefaults: UserDefaultsService())
    return CreateExpenseView(
        viewModel: CreateExpenseViewModel(
            createExpenseUseCase: MockCreateExpenseUseCase(),
            languageService: previewLanguageService
        )
    )
    .environmentObject(previewLanguageService)
}

#endif
