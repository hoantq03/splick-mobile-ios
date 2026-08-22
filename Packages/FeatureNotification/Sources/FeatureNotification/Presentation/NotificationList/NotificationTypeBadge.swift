import SwiftUI
import DesignSystem
import SplickDomain

/// Shared avatar type-chip metrics and fill — keep in lockstep with Android `NotificationTypeBadge`.
enum NotificationTypeBadge {
    static let avatarSize: CGFloat = 48
    static let badgeSize: CGFloat = 20
    static let iconPointSize: CGFloat = 10
    static let ringWidth: CGFloat = 2
    static let overhang: CGFloat = 2

    static var canvasSize: CGFloat { avatarSize + overhang * 2 }

    static func fill(for type: NotificationType) -> Color {
        switch type {
        case .postReactionMilestone:
            return SplickTheme.Colors.error
        case .paymentEvidenceSubmitted, .expenseSplitBill, .dailyDebtReminder,
             .bulkSettlementPendingApproval:
            return SplickTheme.Colors.primaryGradientEnd
        case .paymentEvidenceApproved, .expenseSettled, .bulkSettlementApproved:
            return SplickTheme.Colors.success
        case .paymentEvidenceRejected, .bulkSettlementRejected:
            return SplickTheme.Colors.error
        case .expenseReminder, .streakReminderMidday, .streakReminderEvening:
            return SplickTheme.Colors.warning
        case .directMessage:
            return SplickTheme.Colors.info
        case .system:
            return SplickTheme.Colors.textTertiary
        case .feedTaggedInPost, .postCommented, .feedMentionedInPost, .feedMentionedInComment,
             .friendRequestSent, .friendRequestAccepted, .groupInvite, .groupMessage,
             .groupCreated, .groupMemberAdded, .groupMemberRemoved, .groupRenamed,
             .groupAdminTransferred:
            return SplickTheme.Colors.primaryGradientStart
        }
    }

    static func fill(for type: NotificationType, isRead: Bool) -> Color {
        let color = fill(for: type)
        return isRead ? color.opacity(0.55) : color
    }
}
