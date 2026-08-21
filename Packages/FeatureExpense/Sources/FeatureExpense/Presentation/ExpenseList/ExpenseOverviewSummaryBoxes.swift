import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

struct ExpenseOverviewSummaryBoxes: View {
    let received: Decimal
    let paid: Decimal
    let currency: String
    let incomeLabel: String
    let expenditureLabel: String
    let thisMonthLabel: String
    let todayNet: Decimal
    let todayTitle: String
    let othersOweYouLabel: String
    let youOweOthersLabel: String
    let todayBalancedLabel: String

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            todayBox

            HStack(spacing: SplickTheme.Spacing.sm) {
                summaryBox(
                    title: incomeLabel,
                    amount: received,
                    tint: SplickTheme.Colors.success,
                    icon: "arrow.down.left.circle.fill",
                    caption: thisMonthLabel
                )
                summaryBox(
                    title: expenditureLabel,
                    amount: paid,
                    tint: SplickTheme.Colors.error,
                    icon: "arrow.up.right.circle.fill",
                    caption: thisMonthLabel
                )
            }
        }
    }

    private var todayDirectionLabel: String {
        if todayNet > 0 { return othersOweYouLabel }
        if todayNet < 0 { return youOweOthersLabel }
        return todayBalancedLabel
    }

    private var todayTint: Color {
        if todayNet > 0 { return SplickTheme.Colors.success }
        if todayNet < 0 { return SplickTheme.Colors.error }
        return SplickTheme.Colors.textTertiary
    }

    private var todayIcon: String {
        if todayNet > 0 { return "arrow.down.left.circle.fill" }
        if todayNet < 0 { return "arrow.up.right.circle.fill" }
        return "equal.circle.fill"
    }

    private var todayBox: some View {
        summaryBox(
            title: todayDirectionLabel,
            amount: abs(todayNet),
            tint: todayTint,
            icon: todayIcon,
            caption: todayTitle
        )
    }

    private func summaryBox(
        title: String,
        amount: Decimal,
        tint: Color,
        icon: String,
        caption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            HStack(spacing: SplickTheme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(SplickTheme.Typography.captionBold)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }

            Text(amount.chartAmountString(currencyCode: currency))
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(caption)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
        .padding(SplickTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ExpenseScreenChrome.insetRadius, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ExpenseScreenChrome.insetRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption), \(title), \(amount.chartAmountString(currencyCode: currency))")
    }
}
