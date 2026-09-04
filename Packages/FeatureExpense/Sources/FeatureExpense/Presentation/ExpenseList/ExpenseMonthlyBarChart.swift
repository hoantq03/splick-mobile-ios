import SwiftUI
import Charts
import DesignSystem
import Common
import Localization
import SplickDomain

enum ExpenseChartMode: String, CaseIterable, Identifiable {
    case income
    case expenditure

    var id: String { rawValue }
}

struct ExpenseMonthlyBarChart: View {
    let data: [MonthData]
    let currency: String
    @Binding var selectedMode: ExpenseChartMode
    let incomeLabel: String
    let expenditureLabel: String
    let chartTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            HStack {
                Text(chartTitle)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Spacer(minLength: 0)
                modeToggle
            }

            if data.isEmpty || maxValue <= 0 {
                emptyState
            } else {
                chart
                    .frame(height: 180)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selectedMode)
            }
        }
        .padding(SplickTheme.Spacing.md)
        .splickCard(
            padding: 0,
            cornerRadius: ExpenseScreenChrome.cardRadius
        )
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            toggleButton(mode: .income, label: incomeLabel)
            toggleButton(mode: .expenditure, label: expenditureLabel)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: ExpenseScreenChrome.controlRadius, style: .continuous)
                .fill(SplickTheme.Colors.tertiaryBackground)
        )
    }

    private func toggleButton(mode: ExpenseChartMode, label: String) -> some View {
        let isSelected = selectedMode == mode
        return Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                selectedMode = mode
            }
        } label: {
            Text(label)
                .font(SplickTheme.Typography.captionBold)
                .foregroundStyle(
                    isSelected ? Color.white : SplickTheme.Colors.textSecondary
                )
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, SplickTheme.Spacing.xxs + 2)
                .background {
                    if isSelected {
                        RoundedRectangle(
                            cornerRadius: ExpenseScreenChrome.controlRadius - 2,
                            style: .continuous
                        )
                        .fill(barColor)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var chart: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Month", monthLabel(for: item)),
                y: .value("Amount", Double(truncating: amount(for: item) as NSDecimalNumber))
            )
            .foregroundStyle(barColor.gradient)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(SplickTheme.Colors.textTertiary.opacity(0.35))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(compactAxisLabel(number))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...(maxValue * 1.1))
    }

    private var emptyState: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "chart.bar")
                .font(.system(size: 28))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            Text(selectedMode == .income ? incomeLabel : expenditureLabel)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    private var barColor: Color {
        selectedMode == .income
            ? SplickTheme.Colors.success
            : SplickTheme.Colors.error
    }

    private var maxValue: Double {
        data.map { Double(truncating: amount(for: $0) as NSDecimalNumber) }.max() ?? 0
    }

    private func amount(for item: MonthData) -> Decimal {
        selectedMode == .income ? item.totalSettledReceived : item.totalSettledPaid
    }

    private func monthLabel(for item: MonthData) -> String {
        String(format: "T%d", item.month)
    }

    private func compactAxisLabel(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}
