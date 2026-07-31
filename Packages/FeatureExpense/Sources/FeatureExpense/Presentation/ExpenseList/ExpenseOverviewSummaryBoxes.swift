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

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            summaryBox(
                title: incomeLabel,
                amount: received,
                tint: SplickTheme.Colors.success,
                icon: "arrow.down.left.circle.fill"
            )
            summaryBox(
                title: expenditureLabel,
                amount: paid,
                tint: SplickTheme.Colors.error,
                icon: "arrow.up.right.circle.fill"
            )
        }
    }

    private func summaryBox(
        title: String,
        amount: Decimal,
        tint: Color,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            HStack(spacing: SplickTheme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(SplickTheme.Typography.captionBold)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                Spacer(minLength: 0)
            }

            Text(amount.chartAmountString(currencyCode: currency))
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(thisMonthLabel)
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
    }
}
