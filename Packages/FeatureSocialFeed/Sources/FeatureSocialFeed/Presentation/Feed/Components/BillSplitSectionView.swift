import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct BillSplitSectionView: View {
    @EnvironmentObject private var languageService: LanguageService
    let bill: PostBillSplit
    let onUserTap: (UserSummary) -> Void
    var onSendReminder: ((UserSummary, String) -> Void)?
    var onSendAllReminders: (([UserSummary], String) -> Void)?

    @State private var isExpanded = false
    @State private var reminderTarget: UserSummary?
    @State private var showSendAllReminder = false
    @State private var reminderMessage = ""

    private var unpaidSplits: [PostBillSplitLine] {
        bill.splits.filter { !$0.isPaid }
    }

    private var paidCount: Int {
        bill.splits.filter(\.isPaid).count
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if isExpanded {
                    Button {
                        toggleExpanded()
                    } label: {
                        headerRow
                    }
                    .buttonStyle(.plain)
                } else {
                    headerRow
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isExpanded {
                Divider()
                    .padding(.horizontal, SplickTheme.Spacing.sm)

                expandedContent
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
        .onTapGesture {
            guard !isExpanded else { return }
            toggleExpanded()
        }
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
        .background(
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                .fill(SplickTheme.Colors.tertiaryBackground)
        )
    }

    private var headerRow: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: isFullySettled ? "checkmark.circle.fill" : "dollarsign.circle.fill")
                .font(.body)
                .foregroundStyle(SplickTheme.Colors.success)
            Text(languageService.text(.feedBillSplitTitle))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(
                    isFullySettled
                        ? SplickTheme.Colors.success
                        : SplickTheme.Colors.textSecondary
                )
            Text(formatMoney(bill.totalAmount, currency: bill.currency))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(
                    isFullySettled
                        ? SplickTheme.Colors.success
                        : SplickTheme.Colors.textPrimary
                )
            Spacer()
            if totalCount > 0 {
                Text(languageService.format(.feedBillPaidCount, paidCount, totalCount))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        isFullySettled
                            ? SplickTheme.Colors.success
                            : SplickTheme.Colors.textSecondary
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                isFullySettled
                                    ? SplickTheme.Colors.success.opacity(0.12)
                                    : SplickTheme.Colors.secondaryBackground
                            )
                    )
            }
            if isFullySettled {
                Text(languageService.text(.feedBillSettled))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.success)
            } else {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .contentShape(Rectangle())
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
                    .background(
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                            .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.1))
                    )
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
                        .font(.system(size: 12))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(formatMoney(line.amount, currency: bill.currency))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
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
    }

    private func formatMoney(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
