import XCTest
@testable import Localization

final class CompactRelativeDateTests: XCTestCase {
    func testVietnameseCompactUnits() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-12), appLocale: .vi, now: now),
            "12 giây"
        )
        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-90), appLocale: .vi, now: now),
            "1 phút"
        )
        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-3 * 3600), appLocale: .vi, now: now),
            "3 giờ"
        )
        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-5 * 86400), appLocale: .vi, now: now),
            "5 ngày"
        )
        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-14 * 86400), appLocale: .vi, now: now),
            "2 tuần"
        )
        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-60 * 86400), appLocale: .vi, now: now),
            "2 tháng"
        )
        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-400 * 86400), appLocale: .vi, now: now),
            "1 năm"
        )
    }

    func testEnglishCompactUnits() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-45), appLocale: .en, now: now),
            "45s"
        )
        XCTAssertEqual(
            LocaleFormatting.compactRelativeDate(now.addingTimeInterval(-2 * 86400), appLocale: .en, now: now),
            "2d"
        )
    }
}
