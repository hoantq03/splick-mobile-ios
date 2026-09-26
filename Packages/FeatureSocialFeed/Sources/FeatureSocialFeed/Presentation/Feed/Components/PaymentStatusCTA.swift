import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct PaymentStatusCTA: View {
    @EnvironmentObject private var languageService: LanguageService

    enum Style {
        case pill
        case inline
    }

    let status: PaymentSplitStatus
    var evidenceWasRejected: Bool = false
    var style: Style = .pill
    let onPay: () -> Void

    var body: some View {
        Button(action: onPay) {
            label
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .pill:
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(backgroundColor)
            )
        case .inline:
            HStack(spacing: 3) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .underline()
            }
            .foregroundStyle(foregroundColor)
        }
    }

    private var isActionable: Bool {
        status == .unpaid
    }

    private var title: String {
        switch status {
        case .unpaid:
            return evidenceWasRejected
                ? languageService.text(.feedPaymentStatusResubmitEvidence)
                : languageService.text(.feedPaymentStatusSubmitEvidence)
        case .pendingApproval:
            return languageService.text(.feedPaymentStatusPendingApproval)
        case .paid:
            return languageService.text(.feedPaymentStatusPaid)
        }
    }

    private var iconName: String {
        switch status {
        case .unpaid:
            return evidenceWasRejected ? "arrow.clockwise" : "photo.on.rectangle"
        case .pendingApproval:
            return "clock"
        case .paid:
            return "checkmark.circle.fill"
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
