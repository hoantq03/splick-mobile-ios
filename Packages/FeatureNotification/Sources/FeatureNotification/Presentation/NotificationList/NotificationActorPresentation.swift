import Foundation
import SplickDomain

enum NotificationActorPresentation {
    static func usesSystemAvatar(for type: NotificationType) -> Bool {
        switch type {
        case .streakReminderMidday, .streakReminderEvening, .dailyDebtReminder, .system:
            return true
        default:
            return false
        }
    }

    static func actorDisplayName(for notification: AppNotification) -> String {
        if usesSystemAvatar(for: notification.type) {
            return "Splick"
        }
        if let parsed = parseLeadingActorName(from: notification.body), !parsed.isEmpty {
            return parsed
        }
        return notification.title
    }

    private static func parseLeadingActorName(from body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let delimiters = [
            " and ", " sent you", " accepted your", " tagged you", " mentioned you",
            " commented on", " reacted", " submitted ", " approved ", " rejected ",
            " reminds you", " wants to connect", " added ",
            " và ", " đã gửi", " đã chấp nhận", " đã gắn thẻ", " đã nhắc",
            " đã bình luận", " đã gửi bằng chứng", " đã duyệt", " đã từ chối",
            " nhắc bạn", " bày tỏ",
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
}
