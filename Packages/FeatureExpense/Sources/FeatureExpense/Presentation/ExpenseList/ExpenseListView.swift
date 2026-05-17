import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct ExpenseListView: View {
    @StateObject private var viewModel: ExpenseListViewModel

    public init(viewModel: @autoclosure @escaping () -> ExpenseListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Loading expenses...")

                case .loaded(let expenses) where expenses.isEmpty:
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
            .refreshable { await viewModel.load() }
        }
        .onFirstAppear {
            Task { await viewModel.load() }
        }
    }

    private var expenseContent: some View {
        ScrollView {
            VStack(spacing: SplickTheme.Spacing.md) {
                debtSummaryCard
                expensesList
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
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

    private var expensesList: some View {
        LazyVStack(spacing: SplickTheme.Spacing.xs) {
            ForEach(viewModel.expenses) { expense in
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
