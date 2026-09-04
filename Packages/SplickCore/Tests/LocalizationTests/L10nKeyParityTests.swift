import XCTest
@testable import Localization

final class L10nKeyParityTests: XCTestCase {
    func testViAndEnHaveAllKeys() {
        let viTable = StringsVi.values.merging(StringsFeatureVi.values, uniquingKeysWith: { _, new in new })
        let enTable = StringsEn.values.merging(StringsFeatureEn.values, uniquingKeysWith: { _, new in new })
        for key in L10nKey.allCases {
            XCTAssertNotNil(viTable[key], "Missing Vietnamese string for \(key.rawValue)")
            XCTAssertNotNil(enTable[key], "Missing English string for \(key.rawValue)")
            XCTAssertFalse(viTable[key]?.isEmpty ?? true)
            XCTAssertFalse(enTable[key]?.isEmpty ?? true)
        }
    }

    func testAppLocaleParsesApiValues() {
        XCTAssertEqual(AppLocale.from(apiValue: "en"), .en)
        XCTAssertEqual(AppLocale.from(apiValue: "vi"), .vi)
        XCTAssertEqual(AppLocale.from(apiValue: "fr"), .default)
        XCTAssertEqual(AppLocale.from(apiValue: nil), .default)
    }
}
