import Foundation

extension Date {
    public var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    public var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
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
