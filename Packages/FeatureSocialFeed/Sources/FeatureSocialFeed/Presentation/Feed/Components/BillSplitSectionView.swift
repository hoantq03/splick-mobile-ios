import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct BillSplitSectionView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.currentUserSummary) private var currentUserSummary
    let bill: PostBillSplit
    let onUserTap: (UserSummary) -> Void
    var onSendReminder: ((UserSummary, String) -> Void)?
    var onSendAllReminders: (([UserSummary], String) -> Void)?
    var paymentStatus: PaymentSplitStatus?
    var evidenceWasRejected: Bool = false
    var onPaymentTap: (() -> Void)?

    @State private var isExpanded: Bool
    @State private var reminderTarget: UserSummary?
    @State private var showSendAllReminder = false
    @State private var reminderMessage = ""

    private var unpaidSplits: [PostBillSplitLine] {
        bill.splits.filter { !$0.isPaid }
    }

    private var totalCount: Int {
        bill.splits.count
    }

    private var isFullySettled: Bool {
        unpaidSplits.isEmpty && totalCount > 0
    }

    private var canSendReminders: Bool {
        onSendReminder != nil && onSendAllReminders != nil
    }

    init(
        bill: PostBillSplit,
        onUserTap: @escaping (UserSummary) -> Void,
        initiallyExpanded: Bool = false,
        onSendReminder: ((UserSummary, String) -> Void)? = nil,
        onSendAllReminders: (([UserSummary], String) -> Void)? = nil,
        paymentStatus: PaymentSplitStatus? = nil,
        evidenceWasRejected: Bool = false,
        onPaymentTap: (() -> Void)? = nil
    ) {
        self.bill = bill
        self.onUserTap = onUserTap
        self.onSendReminder = onSendReminder
        self.onSendAllReminders = onSendAllReminders
        self.paymentStatus = paymentStatus
        self.evidenceWasRejected = evidenceWasRejected
        self.onPaymentTap = onPaymentTap
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSummaryRow
                .padding(.vertical, SplickTheme.Spacing.xs)

            if isExpanded {
                Divider()
                    .padding(.horizontal, SplickTheme.Spacing.sm)

                expandedContent
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous))
        .sheet(item: $reminderTarget) { user in
            BillReminderSheet(
                user: user,
                message: $reminderMessage,
                onSend: {
                    onSendReminder?(user, reminderMessage)
                }
            )
        }
        .sheet(isPresented: $showSendAllReminder) {
            BillReminderAllSheet(
                users: unpaidSplits.map(\.user),
                message: $reminderMessage,
                onSend: {
                    onSendAllReminders?(unpaidSplits.map(\.user), reminderMessage)
                }
            )
        }
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .fill(SplickTheme.Colors.tertiaryBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
                }
        }
    }

    private var headerSummaryRow: some View {
        VStack(spacing: SplickTheme.Spacing.xxs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: isFullySettled ? "checkmark.circle.fill" : "dollarsign.circle.fill")
                        .font(.body)
                        .scaleEffect(1.3)
                        .foregroundStyle(SplickTheme.Colors.success)
                        .accessibilityLabel(languageService.text(.feedBillSplitTitle))
                    Text(formatMoney(bill.totalAmount, currency: bill.currency))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(
                            isFullySettled
                                ? SplickTheme.Colors.success
                                : SplickTheme.Colors.textPrimary
                        )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleExpanded()
                }

                Spacer(minLength: 0)

                if let paymentStatus, let onPaymentTap {
                    PaymentStatusCTA(
                        status: paymentStatus,
                        evidenceWasRejected: evidenceWasRejected,
                        onPay: onPaymentTap
                    )
                }
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleExpanded()
                }
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(bill.splits) { line in
                splitRow(line)
            }

            if canSendReminders, !unpaidSplits.isEmpty {
                Button {
                    reminderMessage = BillReminderMessages.random()
                    showSendAllReminder = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(languageService.format(.feedBillRemindAll, unpaidSplits.count))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                            .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.1))
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
        }
    }

    @ViewBuilder
    private func splitRow(_ line: PostBillSplitLine) -> some View {
        let isCurrentUser = line.user.id == currentUserSummary?.id

        HStack(spacing: SplickTheme.Spacing.xs) {
            Button {
                onUserTap(line.user)
            } label: {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    AvatarView(
                        imageURL: line.user.avatarURL,
                        name: line.user.displayName,
                        size: .small
                    )
                    Text(line.user.displayName)
                        .font(.system(size: 12, weight: isCurrentUser ? .semibold : .regular))
                        .foregroundStyle(
                            isCurrentUser
                                ? SplickTheme.Colors.success
                                : SplickTheme.Colors.textSecondary
                        )
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(formatMoney(line.amount, currency: bill.currency))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            isCurrentUser
                                ? SplickTheme.Colors.success
                                : SplickTheme.Colors.textSecondary
                        )
                }
            }
            .buttonStyle(.plain)

            if line.isPaid {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.success)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel(languageService.text(.feedBillPaidAccessibility))
            } else if canSendReminders {
                Button {
                    reminderMessage = BillReminderMessages.random()
                    reminderTarget = line.user
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(languageService.format(.feedBillRemindUserAccessibility, line.user.displayName))
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background {
            if isCurrentUser {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                    .fill(SplickTheme.Colors.success.opacity(0.12))
            }
        }
    }

    private func formatMoney(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
