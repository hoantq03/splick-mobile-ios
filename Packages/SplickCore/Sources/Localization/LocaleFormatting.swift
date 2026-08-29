import Foundation
import Common

public enum LocaleFormatting {
    public static func locale(for appLocale: AppLocale) -> Locale {
        Locale(identifier: appLocale.rawValue)
    }

    public static func currency(code: String, appLocale: AppLocale) -> NumberFormatter {
        SplickMoneyFormat.numberFormatter(maxFractionDigits: code.uppercased() == "VND" ? 0 : 2)
    }

    public static func relativeDate(_ date: Date, appLocale: AppLocale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale(for: appLocale)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Compact social-style ages: `1s`/`1 giây`, `5d`/`5 ngày`, `1w`/`1 tuần`, …
    public static func compactRelativeDate(
        _ date: Date,
        appLocale: AppLocale,
        now: Date = .now
    ) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(date)))
        let value: Int
        let key: L10nKey

        switch elapsed {
        case ..<60:
            value = max(1, elapsed)
            key = .timeCompactSeconds
        case ..<(60 * 60):
            value = max(1, elapsed / 60)
            key = .timeCompactMinutes
        case ..<(60 * 60 * 24):
            value = max(1, elapsed / (60 * 60))
            key = .timeCompactHours
        case ..<(60 * 60 * 24 * 7):
            value = max(1, elapsed / (60 * 60 * 24))
            key = .timeCompactDays
        case ..<(60 * 60 * 24 * 30):
            value = max(1, elapsed / (60 * 60 * 24 * 7))
            key = .timeCompactWeeks
        case ..<(60 * 60 * 24 * 365):
            value = max(1, elapsed / (60 * 60 * 24 * 30))
            key = .timeCompactMonths
        default:
            value = max(1, elapsed / (60 * 60 * 24 * 365))
            key = .timeCompactYears
        }

        return L10n.format(key, locale: appLocale, value)
    }

    /// Last-seen copy for presence subtitles. Hidden when older than 24 hours.
    public static func presenceLastSeen(
        from date: Date,
        appLocale: AppLocale,
        now: Date = .now
    ) -> String? {
        presenceLastSeenBadge(from: date, appLocale: appLocale, now: now)
    }

    /// Avatar badge copy: `5 phút` / `2 giờ`. No seconds, no "ago".
    public static func presenceLastSeenBadge(
        from date: Date,
        appLocale: AppLocale,
        now: Date = .now
    ) -> String? {
        let elapsed = max(0, Int(now.timeIntervalSince(date)))
        guard elapsed <= 24 * 60 * 60 else { return nil }
        if elapsed < 60 * 60 {
            return L10n.format(.timeCompactMinutes, locale: appLocale, max(1, elapsed / 60))
        }
        return L10n.format(.timeCompactHours, locale: appLocale, max(1, elapsed / (60 * 60)))
    }
}
