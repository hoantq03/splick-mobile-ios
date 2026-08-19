import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureStickers

struct BillSplitSectionView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.currentUserSummary) private var currentUserSummary
    let bill: PostBillSplit
    let groupId: UUID?
    let onUserTap: (UserSummary) -> Void
    var onSendReminder: ((UserSummary, String, [CommentSubmissionAttachment]) -> Void)?
    var onSendAllReminders: (([UserSummary], String, [CommentSubmissionAttachment]) -> Void)?
    var makeGifPickerViewModel: GifPickerViewModelFactory?
    var paymentStatus: PaymentSplitStatus?
    var evidenceWasRejected: Bool = false
    var onPaymentTap: (() -> Void)?

    @State private var isExpanded: Bool
    @State private var reminderTarget: UserSummary?
    @State private var showSendAllReminder = false
    @State private var reminderMessage = ""
    @State private var selectedReminderGIF: Sticker?
    @State private var reminderGifPickerViewModel: GifPickerViewModel?

    private enum Layout {
        static let statusFrame: CGFloat = 32
        static let statusIconSize: CGFloat = 18
        /// Compact unpaid status ring / reminder count badge.
        static let reminderBadgeSize: CGFloat = 18
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
            return languageService.text(.feedBillSettled)
        }
        return languageService.format(.feedBillPaidCount, paidCount, totalCount)
    }

    init(
        bill: PostBillSplit,
        groupId: UUID? = nil,
        onUserTap: @escaping (UserSummary) -> Void,
        initiallyExpanded: Bool = false,
        onSendReminder: ((UserSummary, String, [CommentSubmissionAttachment]) -> Void)? = nil,
        onSendAllReminders: (([UserSummary], String, [CommentSubmissionAttachment]) -> Void)? = nil,
        makeGifPickerViewModel: GifPickerViewModelFactory? = nil,
        paymentStatus: PaymentSplitStatus? = nil,
        evidenceWasRejected: Bool = false,
        onPaymentTap: (() -> Void)? = nil
    ) {
        self.bill = bill
        self.groupId = groupId
        self.onUserTap = onUserTap
        self.onSendReminder = onSendReminder
        self.onSendAllReminders = onSendAllReminders
        self.makeGifPickerViewModel = makeGifPickerViewModel
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
                selectedGIF: $selectedReminderGIF,
                gifPickerViewModel: reminderGifPickerViewModel,
                onUserTap: onUserTap,
                onSend: {
                    onSendReminder?(user, reminderMessage, reminderAttachments)
                }
            )
        }
        .sheet(isPresented: $showSendAllReminder) {
            BillReminderAllSheet(
                users: unpaidSplits.map(\.user),
                message: $reminderMessage,
                selectedGIF: $selectedReminderGIF,
                gifPickerViewModel: reminderGifPickerViewModel,
                onUserTap: onUserTap,
                onSend: {
                    onSendAllReminders?(
                        unpaidSplits.map(\.user),
                        reminderMessage,
                        reminderAttachments
                    )
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
                        Text(languageService.text(.feedBillTotalLabel))
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
                    prepareReminderComposer()
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
        let reminderTone = unpaidReminderTone(for: line)

        HStack(spacing: SplickTheme.Spacing.sm) {
            if let reminderTone {
                Capsule(style: .continuous)
                    .fill(reminderTone.accent)
                    .frame(width: 3, height: 28)
            }

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
                            isCurrentUser && line.isPaid
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
                    isCurrentUser && line.isPaid
                        ? SplickTheme.Colors.success
                        : SplickTheme.Colors.textPrimary
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            statusView(for: line)
        }
        .padding(.leading, reminderTone == nil ? SplickTheme.Spacing.sm : SplickTheme.Spacing.xs)
        .padding(.trailing, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                .fill(splitRowBackground(isCurrentUser: isCurrentUser, isPaid: line.isPaid, tone: reminderTone))
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
        } else {
            HStack(spacing: 4) {
                if canSendReminders {
                    Button {
                        prepareReminderComposer()
                        reminderTarget = line.user
                    } label: {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(reminderBellColor(for: line))
                            .frame(width: Layout.statusFrame, height: Layout.statusFrame)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        languageService.format(.feedBillRemindUserAccessibility, line.user.displayName)
                    )
                }

                unpaidStatusGlyph(for: line)
                    .accessibilityLabel(unpaidStatusAccessibilityLabel(for: line))
            }
        }
    }

    private func reminderBellColor(for line: PostBillSplitLine) -> Color {
        unpaidReminderTone(for: line)?.accent ?? SplickTheme.Colors.primaryGradientStart
    }

    private var reminderAttachments: [CommentSubmissionAttachment] {
        guard let selectedReminderGIF else { return [] }
        return [
            CommentSubmissionAttachment(
                kind: .gif,
                remoteURL: selectedReminderGIF.url,
                fileName: "gif-\(selectedReminderGIF.id).gif"
            )
        ]
    }

    private func prepareReminderComposer() {
        reminderMessage = BillReminderMessages.random(using: languageService)
        selectedReminderGIF = nil
        if reminderGifPickerViewModel == nil {
            reminderGifPickerViewModel = makeGifPickerViewModel?(groupId)
        }
    }

    @ViewBuilder
    private func unpaidStatusGlyph(for line: PostBillSplitLine) -> some View {
        let count = line.reminderCount
        let size = Layout.reminderBadgeSize

        if count <= 0 {
            Circle()
                .strokeBorder(SplickTheme.Colors.textTertiary.opacity(0.32), lineWidth: 1.25)
                .frame(width: size, height: size)
                .frame(width: Layout.statusFrame, height: Layout.statusFrame)
        } else {
            let tone = unpaidReminderTone(for: line) ?? .warning
            ZStack {
                Circle()
                    .fill(tone.badgeFill)
                Circle()
                    .strokeBorder(tone.accent.opacity(0.55), lineWidth: 1)
                Text("\(min(count, 99))")
                    .font(.system(size: count >= 10 ? 8 : 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tone.accent)
            }
            .frame(width: size, height: size)
            .frame(width: Layout.statusFrame, height: Layout.statusFrame)
            .accessibilityValue("\(count)")
        }
    }

    private func unpaidStatusAccessibilityLabel(for line: PostBillSplitLine) -> String {
        if line.reminderCount > 0 {
            return languageService.format(.feedBillRemindUserAccessibility, line.user.displayName)
                + ", \(line.reminderCount)"
        }
        return languageService.text(.feedBillUnpaidAccessibility)
    }

    private enum UnpaidReminderTone {
        case warning
        case critical

        var accent: Color {
            switch self {
            case .warning: return SplickTheme.Colors.warning
            case .critical: return SplickTheme.Colors.error
            }
        }

        var badgeFill: Color {
            accent.opacity(0.14)
        }

        var rowFill: Color {
            accent.opacity(0.08)
        }
    }

    private func unpaidReminderTone(for line: PostBillSplitLine) -> UnpaidReminderTone? {
        guard !line.isPaid, line.reminderCount > 0 else { return nil }
        return line.reminderCount >= 3 ? .critical : .warning
    }

    private func splitRowBackground(
        isCurrentUser: Bool,
        isPaid: Bool,
        tone: UnpaidReminderTone?
    ) -> Color {
        if let tone {
            return tone.rowFill
        }
        if isCurrentUser && isPaid {
            return SplickTheme.Colors.success.opacity(0.12)
        }
        return .clear
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
            return languageService.text(.feedPaymentStatusSubmitEvidence)
        case .rejected:
            return languageService.text(.feedPaymentStatusResubmitEvidence)
        case .pendingApproval:
            return languageService.text(.feedPaymentStatusPendingApproval)
        case .paid:
            return languageService.text(.feedPaymentStatusPaid)
        }
    }

    private func paymentEvidenceSubtitle(for state: PaymentEvidenceDisplayState) -> String {
        switch state {
        case .upload:
            return languageService.text(.feedPaymentStatusHintUnpaid)
        case .rejected:
            return languageService.text(.feedPaymentStatusHintResubmit)
        case .pendingApproval:
            return languageService.text(.feedPaymentStatusHintPending)
        case .paid:
            return languageService.text(.feedPaymentStatusHintPaid)
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
            return languageService.text(.commonMe)
        }

        let trimmedName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return user.displayName }

        let components = trimmedName.split(whereSeparator: \.isWhitespace)
        return components.last.map(String.init) ?? trimmedName
    }

    private func formatMoney(_ amount: Decimal, currency: String) -> String {
        let symbol = Decimal.displayCurrencySymbol(for: currency)
        let numberPart = SplickMoneyFormat.string(from: amount)
        if currency.uppercased() == "USD" {
            return "\(symbol)\(numberPart)"
        }
        return "\(numberPart)\(symbol)"
    }
}
