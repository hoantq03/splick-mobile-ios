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

    /// Monday-first, two-character labels. Vietnamese: T2…T7, CN. Sunday is last so it matches the grid.
    static func weekdaySymbols(locale: Locale = .current) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        let veryShort = formatter.veryShortStandaloneWeekdaySymbols ?? []
        let short = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        let sundayFirst = (0..<7).map { index in
            twoCharacterSymbol(
                veryShort: symbol(veryShort, at: index),
                short: symbol(short, at: index)
            )
        }
        guard sundayFirst.count == 7, sundayFirst.allSatisfy({ !$0.isEmpty }) else {
            return ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
        }
        return Array(sundayFirst.dropFirst()) + [sundayFirst[0]]
    }

    private static func symbol(_ symbols: [String], at index: Int) -> String {
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    /// Prefer the locale's two-character form (`T2`, `CN`). Longer names collapse to two letters (`Mon` → `Mo`).
    private static func twoCharacterSymbol(veryShort: String, short: String) -> String {
        if veryShort.count == 2 {
            return veryShort
        }
        let compact = short.replacingOccurrences(of: " ", with: "")
        if compact.count >= 2 {
            return String(compact.prefix(2))
        }
        if veryShort.count >= 2 {
            return String(veryShort.prefix(2))
        }
        return compact.isEmpty ? veryShort : compact
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
