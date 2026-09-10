import Foundation
import SplickDomain

enum NotificationActorPresentation {
    /// System-originated rows (scheduler / Splick). Everyone else is an actor: sender,
    /// requester, reviewer, inviter, commenter, etc.
    static func usesSystemAvatar(for notification: AppNotification) -> Bool {
        if isSystemOriginType(notification.type) { return true }
        return notification.type == .expenseReminder && isAutoExpenseReminder(notification.body)
    }

    static func usesSystemAvatar(for type: NotificationType) -> Bool {
        isSystemOriginType(type)
    }

    static func actorDisplayName(for notification: AppNotification) -> String {
        if usesSystemAvatar(for: notification) {
            return "Splick"
        }
        if let parsed = parseLeadingActorName(from: notification.body), !parsed.isEmpty {
            return parsed
        }
        return notification.title
    }

    /// Older `FRIEND_REQUEST_ACCEPTED` rows stored only the accepter's name as the body.
    /// Older `GROUP_INVITE` rows used a shorter “invited you to join {group}” sentence.
    static func expandedBody(
        for notification: AppNotification,
        friendAcceptedDescription: (String) -> String,
        groupInviteDescription: ((String, String) -> String)? = nil
    ) -> String {
        let body = notification.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if notification.type == .friendRequestAccepted,
           !body.isEmpty,
           parseLeadingActorName(from: body) == nil {
            return friendAcceptedDescription(body)
        }
        if notification.type == .groupInvite {
            return expandGroupInvite(
                notification,
                groupInviteDescription ?? { _, _ in notification.body }
            )
        }
        return notification.body
    }

    /// Splits notification body into a leading actor name (bold) and the remainder.
    static func bodySegments(for notification: AppNotification) -> (actorName: String?, remainder: String) {
        let body = notification.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !usesSystemAvatar(for: notification) else {
            return (nil, body)
        }

        if let name = parseLeadingActorName(from: body),
           body.lowercased().hasPrefix(name.lowercased()) {
            let remainderIndex = body.index(body.startIndex, offsetBy: name.count)
            let remainder = String(body[remainderIndex...]).trimmingCharacters(in: .whitespaces)
            return (name, remainder)
        }

        return (nil, body)
    }

    private static func parseLeadingActorName(from body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let delimiters = [
            " and ", " sent you", " invited you", " accepted your", " tagged you", " mentioned you",
            " commented on", " reacted", " submitted ", " approved ", " rejected ",
            " reminds you", " wants to connect", " added ",
            " set your nickname", " removed your nickname",
            " và ", " đã gửi", " đã mời", " đã chấp nhận", " đã gắn thẻ", " đã nhắc",
            " đã bình luận", " đã gửi bằng chứng", " đã duyệt", " đã từ chối",
            " nhắc bạn", " bày tỏ", " đã đặt biệt danh", " đã xóa biệt danh",
        ]

        let lowercased = trimmed.lowercased()
        for delimiter in delimiters {
            guard let range = lowercased.range(of: delimiter) else { continue }
            let name = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        return nil
    }

    private static func isSystemOriginType(_ type: NotificationType) -> Bool {
        switch type {
        case .streakReminderMidday, .streakReminderEvening, .dailyDebtReminder, .system:
            return true
        default:
            return false
        }
    }

    private static func isAutoExpenseReminder(_ body: String) -> Bool {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("Nhắc nhở:") || trimmed.hasPrefix("Reminder:")
    }

    private static func expandGroupInvite(
        _ notification: AppNotification,
        _ format: (String, String) -> String
    ) -> String {
        let body = notification.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = body.lowercased()
        if lower.contains("tham gia nhóm") || lower.contains("join the group") {
            return notification.body
        }
        let viMarker = " đã mời bạn tham gia "
        let enMarker = " invited you to join "
        if let range = lower.range(of: viMarker), range.lowerBound > lower.startIndex {
            let actorEnd = body.index(body.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
            let groupStart = body.index(actorEnd, offsetBy: viMarker.count)
            let actor = String(body[..<actorEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            let group = String(body[groupStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !actor.isEmpty, !group.isEmpty else { return notification.body }
            return format(actor, group)
        }
        if let range = lower.range(of: enMarker), range.lowerBound > lower.startIndex {
            let actorEnd = body.index(body.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
            let groupStart = body.index(actorEnd, offsetBy: enMarker.count)
            let actor = String(body[..<actorEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            var group = String(body[groupStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if group.lowercased().hasPrefix("the group ") {
                group = String(group.dropFirst("the group ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !actor.isEmpty, !group.isEmpty else { return notification.body }
            return format(actor, group)
        }
        return notification.body
    }
}
