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
}
