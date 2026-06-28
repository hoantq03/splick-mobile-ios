import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct PaymentStatusCTA: View {
    @EnvironmentObject private var languageService: LanguageService

    let status: PaymentSplitStatus
    let onPay: () -> Void

    var body: some View {
        Button(action: onPay) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
    }

    private var isActionable: Bool {
        status == .unpaid
    }

    private var title: String {
        switch status {
        case .unpaid:
            return languageService.text(.feedPaymentPay)
        case .pendingApproval:
            return languageService.text(.feedPaymentPending)
        case .paid:
            return languageService.text(.feedPaymentPaid)
        }
    }

    private var iconName: String {
        switch status {
        case .unpaid: return "banknote"
        case .pendingApproval: return "clock"
        case .paid: return "checkmark.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .unpaid:
            return SplickTheme.Colors.primaryGradientStart
        case .pendingApproval:
            return SplickTheme.Colors.textSecondary
        case .paid:
            return SplickTheme.Colors.success
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .unpaid:
            return SplickTheme.Colors.primaryGradientStart.opacity(0.12)
        case .pendingApproval, .paid:
            return SplickTheme.Colors.tertiaryBackground
        }
    }
}
