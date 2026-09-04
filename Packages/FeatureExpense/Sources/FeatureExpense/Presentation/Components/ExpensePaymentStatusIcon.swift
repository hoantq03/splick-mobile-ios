import DesignSystem
import Localization
import SplickDomain
import SwiftUI

struct ExpensePaymentStatusIcon: View {
    @EnvironmentObject private var languageService: LanguageService

    let status: ExpensePaymentDisplayStatus

    var body: some View {
        Group {
            switch status {
            case .paid:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.success)
                    .accessibilityLabel(languageService.text(.expenseRowPaidAccessibility))
            case .pendingApproval:
                Image(systemName: "clock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.warning)
                    .accessibilityLabel(languageService.text(.expenseRowPendingApprovalAccessibility))
            case .unpaid:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.error)
                    .accessibilityLabel(languageService.text(.expenseRowUnpaidAccessibility))
            case .neutral:
                EmptyView()
            }
        }
        .frame(width: status == .neutral ? 0 : 32, height: 32)
    }
}
