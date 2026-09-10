import Foundation
import Localization
import SplickDomain

enum NotificationTimeSection: Int, CaseIterable, Hashable {
    case today
    case yesterday
    case pastWeek
    case pastMonth
    case pastYear

    var l10nKey: L10nKey {
        switch self {
        case .today: return .notificationSectionToday
        case .yesterday: return .notificationSectionYesterday
        case .pastWeek: return .notificationSectionPastWeek
        case .pastMonth: return .notificationSectionPastMonth
        case .pastYear: return .notificationSectionPastYear
        }
    }

    static func resolve(
        for date: Date,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> NotificationTimeSection {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let dayOffset = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        switch dayOffset {
        case ..<0, 0:
            return .today
        case 1:
            return .yesterday
        case 2..<7:
            return .pastWeek
        case 7..<30:
            return .pastMonth
        default:
            return .pastYear
        }
    }
}

struct NotificationListSection: Identifiable {
    let section: NotificationTimeSection
    let notifications: [AppNotification]

    var id: NotificationTimeSection { section }

    static func grouped(from notifications: [AppNotification]) -> [NotificationListSection] {
        var buckets: [NotificationTimeSection: [AppNotification]] = [:]
        var order: [NotificationTimeSection] = []

        for notification in notifications {
            let section = NotificationTimeSection.resolve(for: notification.createdAt)
            if buckets[section] == nil {
                buckets[section] = []
                order.append(section)
            }
            buckets[section]?.append(notification)
        }

        return order.map { section in
            NotificationListSection(section: section, notifications: buckets[section] ?? [])
        }
    }
}
