import Foundation
import SwiftUI
import SplickDomain

struct StreakMonthSection: Identifiable, Equatable {
    let year: Int
    let month: Int
    let days: [StreakDay]

    var id: String { "\(year)-\(String(format: "%02d", month))" }

    var monthDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? .now
    }

    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate)
    }
}

enum StreakCalendarLayout {
    static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    static let cellCornerRadius: CGFloat = 6

    static func weekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        return symbols.map { String($0.prefix(1)) }
    }

    /// Empty leading cells so day 1 aligns to the correct weekday column (Mon-start grid).
    static func leadingEmptyCellCount(year: Int, month: Int, calendar: Calendar = .current) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday + 5) % 7
    }
}
