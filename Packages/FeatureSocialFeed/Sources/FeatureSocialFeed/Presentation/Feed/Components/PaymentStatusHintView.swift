import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct PaymentStatusHintView: View {
    @EnvironmentObject private var languageService: LanguageService

    let status: PaymentSplitStatus
    let authorName: String
    var evidenceWasRejected: Bool = false
    let onAction: () -> Void

    private var hintFont: Font { .system(size: 11) }

    var body: some View {
        Group {
            switch status {
            case .unpaid:
                actionableHint(
                    prefix: evidenceWasRejected
                        ? languageService.text(.feedPaymentStatusHintResubmit)
                        : languageService.format(.feedPaymentStatusHintUnpaid, authorName)
                )
            case .pendingApproval:
                Text(languageService.format(.feedPaymentStatusHintPending, authorName))
                    .font(hintFont)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .paid:
                Text(languageService.format(.feedPaymentStatusHintPaid, authorName))
                    .font(hintFont)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func actionableHint(prefix: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(prefix)
                    .font(hintFont)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                inlineActionButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(prefix)
                    .font(hintFont)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                inlineActionButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inlineActionButton: some View {
        PaymentStatusCTA(
            status: status,
            evidenceWasRejected: evidenceWasRejected,
            style: .inline,
            onPay: onAction
        )
    }
}
