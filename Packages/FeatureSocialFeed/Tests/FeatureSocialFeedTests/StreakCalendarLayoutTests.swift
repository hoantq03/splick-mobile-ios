import XCTest
@testable import FeatureSocialFeed

final class StreakCalendarLayoutTests: XCTestCase {
    func testVietnameseWeekdaySymbolsAreTwoCharactersWithSundayLast() {
        let symbols = StreakCalendarLayout.weekdaySymbols(locale: Locale(identifier: "vi"))
        XCTAssertEqual(symbols, ["T2", "T3", "T4", "T5", "T6", "T7", "CN"])
    }

    func testEnglishWeekdaySymbolsAreTwoCharactersWithSundayLast() {
        let symbols = StreakCalendarLayout.weekdaySymbols(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(symbols, ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"])
    }
}
