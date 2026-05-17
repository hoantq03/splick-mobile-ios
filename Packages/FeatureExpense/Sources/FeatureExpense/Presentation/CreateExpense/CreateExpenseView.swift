import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct CreateExpenseView: View {
    @StateObject private var viewModel: CreateExpenseViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: @autoclosure @escaping () -> CreateExpenseViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    amountSection
                    detailsSection
                    categorySection
                    splitTypeSection
                    actionSection
                }
                .padding(SplickTheme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: viewModel.state) { newState in
                if case .loaded = newState { dismiss() }
            }
        }
    }

    private var amountSection: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            Text("How much?")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: SplickTheme.Spacing.xxs) {
                Text("₫")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                TextField("0", text: $viewModel.amount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)

            if let error = viewModel.amountError {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
        .padding(.vertical, SplickTheme.Spacing.lg)
    }

    private var detailsSection: some View {
        SplickTextField(
            "What's this for?",
            text: $viewModel.description,
            errorMessage: viewModel.descriptionError,
            icon: "text.alignleft"
        )
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text("Category")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        categoryChip(category)
                    }
                }
            }
        }
    }

    private func categoryChip(_ category: ExpenseCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            viewModel.selectedCategory = category
        } label: {
            HStack(spacing: SplickTheme.Spacing.xxs) {
                Image(systemName: category.icon)
                Text(category.displayName)
                    .font(SplickTheme.Typography.caption)
            }
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .padding(.vertical, SplickTheme.Spacing.xs)
            .background(isSelected ? SplickTheme.Colors.primaryGradientStart : SplickTheme.Colors.secondaryBackground)
            .foregroundStyle(isSelected ? .white : SplickTheme.Colors.textPrimary)
            .clipShape(Capsule())
        }
    }

    private var splitTypeSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text("Split Type")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            Picker("Split Type", selection: $viewModel.splitType) {
                ForEach(SplitType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var actionSection: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            if let error = viewModel.state.error {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }

            SplickButton(
                "Create Expense",
                isLoading: viewModel.state.isLoading,
                isDisabled: viewModel.description.isEmpty || viewModel.amount.isEmpty
            ) {
                Task { await viewModel.createExpense() }
            }
        }
    }
}
