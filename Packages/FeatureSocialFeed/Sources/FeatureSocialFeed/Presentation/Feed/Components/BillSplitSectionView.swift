import SwiftUI
import DesignSystem
import SplickDomain

struct BillSplitSectionView: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.body)
                        .foregroundStyle(SplickTheme.Colors.success)
                    Text("Chia bill")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                    Text(formatMoney(bill.totalAmount, currency: bill.currency))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, SplickTheme.Spacing.xs)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, SplickTheme.Spacing.sm)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(bill.splits) { line in
                        splitRow(line)
                    }

                    if !unpaidSplits.isEmpty {
                        Button {
                            reminderMessage = BillReminderMessages.random()
                            showSendAllReminder = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Nhắc tất cả (\(unpaidSplits.count))")
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
                    .accessibilityLabel("Đã thanh toán")
            } else {
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
                .accessibilityLabel("Nhắc \(line.user.displayName)")
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
