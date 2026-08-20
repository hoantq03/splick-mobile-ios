import SwiftUI
import DesignSystem
import Localization

enum MessageTimeSeparatorFormatter {
    static func string(
        from date: Date,
        locale: AppLocale,
        yesterdayLabel: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let time = timeString(from: date, timeZone: calendar.timeZone)
        var calendar = calendar
        calendar.locale = Locale(identifier: locale.rawValue)

        if calendar.isDate(date, inSameDayAs: now) {
            return time
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "\(yesterdayLabel) \(time)"
        }

        let startOfNow = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let daysAgo = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? Int.max

        if daysAgo > 0, daysAgo < 7 {
            return "\(weekdayString(from: date, locale: locale, timeZone: calendar.timeZone)) \(time)"
        }

        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let datePart = sameYear
            ? monthDayString(from: date, locale: locale, timeZone: calendar.timeZone)
            : fullDateString(from: date, locale: locale, timeZone: calendar.timeZone)
        return "\(datePart) \(time)"
    }

    private static func timeString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func weekdayString(from date: Date, locale: AppLocale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.rawValue)
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private static func monthDayString(from date: Date, locale: AppLocale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.rawValue)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private static func fullDateString(from date: Date, locale: AppLocale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.rawValue)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return formatter.string(from: date)
    }
}

struct MessageTimeSeparatorLabel: View {
    @EnvironmentObject private var languageService: LanguageService

    let date: Date

    var body: some View {
        Text(
            MessageTimeSeparatorFormatter.string(
                from: date,
                locale: languageService.locale,
                yesterdayLabel: languageService.text(.notificationSectionYesterday)
            )
        )
        .font(SplickTheme.Typography.caption.weight(.medium))
        .foregroundStyle(SplickTheme.Colors.textTertiary)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.xs)
        .accessibilityAddTraits(.isHeader)
    }
}
