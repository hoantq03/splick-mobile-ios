import XCTest
@testable import Localization

final class L10nKeyParityTests: XCTestCase {
    func testViAndEnHaveAllKeys() {
        for key in L10nKey.allCases {
            XCTAssertNotNil(StringsVi.values[key], "Missing Vietnamese string for \(key.rawValue)")
            XCTAssertNotNil(StringsEn.values[key], "Missing English string for \(key.rawValue)")
            XCTAssertFalse(StringsVi.values[key]?.isEmpty ?? true)
            XCTAssertFalse(StringsEn.values[key]?.isEmpty ?? true)
        }
    }

    func testAppLocaleParsesApiValues() {
        XCTAssertEqual(AppLocale.from(apiValue: "en"), .en)
        XCTAssertEqual(AppLocale.from(apiValue: "vi"), .vi)
        XCTAssertEqual(AppLocale.from(apiValue: "fr"), .default)
        XCTAssertEqual(AppLocale.from(apiValue: nil), .default)
    }
}
