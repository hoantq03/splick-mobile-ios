import Foundation

public enum SplickRelativeDateFormatters {
    public static let abbreviated: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static let full: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    public static func apply(locale: Locale) {
        abbreviated.locale = locale
        full.locale = locale
    }
}

extension Date {
    public var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    public var relativeString: String {
        SplickRelativeDateFormatters.abbreviated.localizedString(for: self, relativeTo: .now)
    }

    /// Long-form relative time for expense rows, e.g. "2 hours ago" / "2 giờ trước".
    public var expenseListRelativeString: String {
        SplickRelativeDateFormatters.full.localizedString(for: self, relativeTo: .now)
    }

    public var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    public var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    public static func from(iso8601 string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }

    private static let apiCalendarDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public var apiCalendarDateString: String {
        Self.apiCalendarDateFormatter.string(from: self)
    }

    public static func from(apiCalendarDate string: String) -> Date? {
        apiCalendarDateFormatter.date(from: string)
    }
}
