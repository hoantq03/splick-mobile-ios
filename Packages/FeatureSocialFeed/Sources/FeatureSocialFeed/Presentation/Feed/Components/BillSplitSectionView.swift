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

    private enum Layout {
        static let statusFrame: CGFloat = 32
        static let statusIconSize: CGFloat = 18
        static let participantColumnWidth: CGFloat = 116
    }

    private enum PaymentEvidenceDisplayState {
        case upload
        case rejected
        case pendingApproval
        case paid
    }

    private var unpaidSplits: [PostBillSplitLine] {
        bill.splits.filter { !$0.isPaid }
    }

    private var paidCount: Int {
        bill.splits.count - unpaidSplits.count
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

    private var paymentEvidenceDisplayState: PaymentEvidenceDisplayState? {
        guard let paymentStatus else { return nil }

        switch paymentStatus {
        case .paid:
            return .paid
        case .pendingApproval:
            return .pendingApproval
        case .unpaid:
            return evidenceWasRejected ? .rejected : .upload
        }
    }

    private var settlementBadgeTitle: String {
        if isFullySettled {
            return "Đã thanh tất toán"
        }
        return "\(paidCount)/\(totalCount) đã trả"
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
                onUserTap: onUserTap,
                onSend: {
                    onSendReminder?(user, reminderMessage)
                }
            )
        }
        .sheet(isPresented: $showSendAllReminder) {
            BillReminderAllSheet(
                users: unpaidSplits.map(\.user),
                message: $reminderMessage,
                onUserTap: onUserTap,
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
        VStack(spacing: 0) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: isFullySettled ? "checkmark.circle.fill" : "dollarsign.circle.fill")
                        .font(.body)
                        .scaleEffect(1.3)
                        .foregroundStyle(
                            isFullySettled
                                ? SplickTheme.Colors.success
                                : SplickTheme.Colors.primaryGradientStart
                        )
                        .accessibilityLabel(languageService.text(.feedBillSplitTitle))
                    HStack(spacing: 4) {
                        Text("Tổng")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                        Text(formatMoney(bill.totalAmount, currency: bill.currency))
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(
                                isFullySettled
                                    ? SplickTheme.Colors.success
                                    : SplickTheme.Colors.textPrimary
                            )
                    }
                }

                Spacer(minLength: 0)

                settlementBadge
            }
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleExpanded()
            }

            if let paymentEvidenceDisplayState {
                paymentEvidenceStatusBlock(for: paymentEvidenceDisplayState)
                    .padding(.top, SplickTheme.Spacing.md)
                    .padding(.horizontal, SplickTheme.Spacing.sm)
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 16)
                .padding(.top, SplickTheme.Spacing.xs)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleExpanded()
                }
        }
        .padding(.top, SplickTheme.Spacing.sm)
        .padding(.bottom, SplickTheme.Spacing.xs)
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

        HStack(spacing: SplickTheme.Spacing.sm) {
            Button {
                onUserTap(line.user)
            } label: {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    AvatarView(
                        imageURL: line.user.avatarURL,
                        name: line.user.displayName,
                        size: .small
                    )
                    Text(compactDisplayName(for: line.user, isCurrentUser: isCurrentUser))
                        .font(.system(size: 12, weight: isCurrentUser ? .semibold : .regular))
                        .foregroundStyle(
                            isCurrentUser
                                ? SplickTheme.Colors.success
                                : SplickTheme.Colors.textSecondary
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                }
                .frame(width: Layout.participantColumnWidth)
            }
            .buttonStyle(.plain)

            Text(formatMoney(line.amount, currency: bill.currency))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    isCurrentUser
                        ? SplickTheme.Colors.success
                        : SplickTheme.Colors.textPrimary
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            statusView(for: line)
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

    @ViewBuilder
    private func statusView(for line: PostBillSplitLine) -> some View {
        if line.isPaid {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Layout.statusIconSize, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.success)
                .frame(width: Layout.statusFrame, height: Layout.statusFrame)
                .accessibilityLabel(languageService.text(.feedBillPaidAccessibility))
        } else if canSendReminders {
            Button {
                reminderMessage = BillReminderMessages.random()
                reminderTarget = line.user
            } label: {
                Image(systemName: "bell.badge")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: Layout.statusFrame, height: Layout.statusFrame)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageService.format(.feedBillRemindUserAccessibility, line.user.displayName))
        } else {
            Circle()
                .strokeBorder(SplickTheme.Colors.textTertiary.opacity(0.35), lineWidth: 2)
                .frame(width: Layout.statusIconSize, height: Layout.statusIconSize)
                .frame(width: Layout.statusFrame, height: Layout.statusFrame)
                .accessibilityLabel("Chưa thanh toán")
        }
    }

    @ViewBuilder
    private func paymentEvidenceStatusBlock(for state: PaymentEvidenceDisplayState) -> some View {
        let content = paymentEvidenceStatusContent(for: state)

        if case .upload = state, let onPaymentTap {
            Button(action: onPaymentTap) {
                content
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if case .rejected = state, let onPaymentTap {
            Button(action: onPaymentTap) {
                content
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func paymentEvidenceStatusContent(for state: PaymentEvidenceDisplayState) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: paymentEvidenceIconName(for: state))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(paymentEvidenceAccentColor(for: state))

            VStack(alignment: .leading, spacing: 2) {
                Text(paymentEvidenceTitle(for: state))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text(paymentEvidenceSubtitle(for: state))
                    .font(.system(size: 11))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if paymentEvidenceShowsChevron(for: state) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                .fill(paymentEvidenceBackgroundColor(for: state))
        }
    }

    private func paymentEvidenceTitle(for state: PaymentEvidenceDisplayState) -> String {
        switch state {
        case .upload:
            return "Upload ảnh chuyển khoản"
        case .rejected:
            return "Upload lại ảnh chuyển khoản"
        case .pendingApproval:
            return "Đang chờ duyệt"
        case .paid:
            return "Đã thanh toán"
        }
    }

    private func paymentEvidenceSubtitle(for state: PaymentEvidenceDisplayState) -> String {
        switch state {
        case .upload:
            return "Chọn ảnh và nộp để chủ xị duyệt ảnh chuyển khoản."
        case .rejected:
            return "Ồ nooo, ảnh của bạn bị chủ xị từ chối rồi, hãy upload lại."
        case .pendingApproval:
            return "Ảnh chuyển khoản của bạn đang chờ chủ xị xác nhận."
        case .paid:
            return "Tuyệt vời, khoản thanh toán của bạn đã được chủ xị xác nhận thành công."
        }
    }

    private func paymentEvidenceIconName(for state: PaymentEvidenceDisplayState) -> String {
        switch state {
        case .upload:
            return "icloud.and.arrow.up"
        case .rejected:
            return "exclamationmark.circle.fill"
        case .pendingApproval:
            return "clock.badge"
        case .paid:
            return "checkmark.circle.fill"
        }
    }

    private func paymentEvidenceAccentColor(for state: PaymentEvidenceDisplayState) -> Color {
        switch state {
        case .upload:
            return SplickTheme.Colors.primaryGradientStart
        case .rejected:
            return Color(red: 0.79, green: 0.56, blue: 0.08)
        case .pendingApproval:
            return Color(red: 0.79, green: 0.56, blue: 0.08)
        case .paid:
            return SplickTheme.Colors.success
        }
    }

    private func paymentEvidenceBackgroundColor(for state: PaymentEvidenceDisplayState) -> Color {
        switch state {
        case .upload:
            return SplickTheme.Colors.primaryGradientStart.opacity(0.08)
        case .rejected, .pendingApproval:
            return Color(red: 1.0, green: 0.96, blue: 0.84)
        case .paid:
            return SplickTheme.Colors.success.opacity(0.1)
        }
    }

    private func paymentEvidenceShowsChevron(for state: PaymentEvidenceDisplayState) -> Bool {
        switch state {
        case .upload, .rejected:
            return true
        case .pendingApproval, .paid:
            return false
        }
    }

    private var settlementBadge: some View {
        Text(settlementBadgeTitle)
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(isFullySettled ? SplickTheme.Colors.success : Color(red: 0.72, green: 0.47, blue: 0.04))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(
                        isFullySettled
                            ? SplickTheme.Colors.success.opacity(0.12)
                            : Color(red: 0.98, green: 0.93, blue: 0.76)
                    )
            }
    }

    private func compactDisplayName(for user: UserSummary, isCurrentUser: Bool) -> String {
        if isCurrentUser {
            return "Tôi"
        }

        let trimmedName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return user.displayName }

        let components = trimmedName.split(whereSeparator: \.isWhitespace)
        return components.last.map(String.init) ?? trimmedName
    }

    private func formatMoney(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
