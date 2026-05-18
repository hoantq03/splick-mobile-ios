import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct ExpenseListView: View {
    @StateObject private var viewModel: ExpenseListViewModel
    @StateObject private var userSearchViewModel: ExpenseUserSearchViewModel
    private let currentUserId: UUID?

    public init(
        viewModel: @autoclosure @escaping () -> ExpenseListViewModel,
        userSearchUseCase: UserSearchUseCaseProtocol? = nil,
        currentUserId: UUID? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        _userSearchViewModel = StateObject(
            wrappedValue: ExpenseUserSearchViewModel(useCase: userSearchUseCase)
        )
        self.currentUserId = currentUserId
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Loading expenses...")

                case .loaded where viewModel.expenses.isEmpty:
                    EmptyStateView(
                        icon: "dollarsign.circle",
                        title: "No Expenses",
                        message: "Create your first shared expense to start splitting bills.",
                        actionTitle: "Add Expense"
                    ) {
                        viewModel.showCreateExpense = true
                    }

                case .loaded:
                    expenseContent

                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showCreateExpense = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                }
            }
            .refreshable { await viewModel.load(isPullToRefresh: true) }
        }
        .onFirstAppear {
            viewModel.updateCurrentUserId(currentUserId)
            Task { await viewModel.load() }
        }
        .onChange(of: currentUserId) { userId in
            viewModel.updateCurrentUserId(userId)
        }
    }

    private var expenseContent: some View {
        let displayed = viewModel.filteredExpenses
        return ScrollView {
            VStack(spacing: SplickTheme.Spacing.md) {
                ExpenseFilterBarView(
                    viewModel: viewModel,
                    userSearchViewModel: userSearchViewModel
                )

                VStack(spacing: SplickTheme.Spacing.md) {
                    debtSummaryCard

                    if displayed.isEmpty {
                        filteredEmptyState
                    } else {
                        expensesList(displayed)
                    }
                }
                .id(viewModel.filterSignature)
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            Text("No matching expenses")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
            Text("Try changing filters or clearing them.")
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SplickTheme.Spacing.xl)
        .splickCard()
    }

    private var debtSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                Text("You are owed")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                Text(formatAmount(viewModel.totalOwed))
                    .font(SplickTheme.Typography.title)
                    .foregroundStyle(SplickTheme.Colors.success)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: SplickTheme.Spacing.xxs) {
                Text("You owe")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                Text(formatAmount(viewModel.totalOwing))
                    .font(SplickTheme.Typography.title)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
        .splickCard()
    }

    private func expensesList(_ expenses: [Expense]) -> some View {
        LazyVStack(spacing: SplickTheme.Spacing.xs) {
            ForEach(expenses) { expense in
                ExpenseRowView(expense: expense)
            }
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

struct ExpenseRowView: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: expense.category.icon)
                .font(.title3)
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .frame(width: 40, height: 40)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(expense.description)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text("Paid by \(expense.paidBy.displayName)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                Text("Created \(expense.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)

                if let settledAt = expense.displaySettledAt {
                    Text("Settled \(settledAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.success.opacity(0.85))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: SplickTheme.Spacing.xxxs) {
                Text(formatAmount(expense.totalAmount))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)

                statusBadge
            }
        }
        .splickCard()
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color) = statusInfo
        Text(text)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, SplickTheme.Spacing.xs)
            .padding(.vertical, SplickTheme.Spacing.xxxs)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private var statusInfo: (String, Color) {
        switch expense.status {
        case .pending: return ("Pending", SplickTheme.Colors.warning)
        case .partiallySettled: return ("Partial", SplickTheme.Colors.info)
        case .settled: return ("Settled", SplickTheme.Colors.success)
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = expense.currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
