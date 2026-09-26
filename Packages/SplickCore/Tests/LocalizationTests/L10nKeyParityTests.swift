import XCTest
import SwiftUI
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

    func testAppThemeParsesStoredValues() {
        XCTAssertEqual(AppTheme.from(storedValue: "light"), .light)
        XCTAssertEqual(AppTheme.from(storedValue: "DARK"), .dark)
        XCTAssertEqual(AppTheme.from(storedValue: "system"), .system)
        XCTAssertEqual(AppTheme.from(storedValue: "unknown"), .default)
        XCTAssertEqual(AppTheme.from(storedValue: nil), .default)
        XCTAssertNil(AppTheme.system.preferredColorScheme)
        XCTAssertEqual(AppTheme.light.preferredColorScheme, .light)
        XCTAssertEqual(AppTheme.dark.preferredColorScheme, .dark)
        XCTAssertTrue(AppTheme.dark.usesDarkAppIcon(systemIsDark: false))
        XCTAssertFalse(AppTheme.light.usesDarkAppIcon(systemIsDark: true))
        XCTAssertTrue(AppTheme.system.usesDarkAppIcon(systemIsDark: true))
        XCTAssertFalse(AppTheme.system.usesDarkAppIcon(systemIsDark: false))
        XCTAssertEqual(AppTheme.light.visualTheme(systemIsDark: true), .light)
        XCTAssertEqual(AppTheme.dark.visualTheme(systemIsDark: false), .dark)
        XCTAssertEqual(AppTheme.system.visualTheme(systemIsDark: true), .dark)
        XCTAssertEqual(AppTheme.system.visualTheme(systemIsDark: false), .light)
    }

    func testSplickColorThemeParsesStoredValues() {
        XCTAssertEqual(SplickColorTheme.from(storedValue: "default"), .default)
        XCTAssertEqual(SplickColorTheme.from(storedValue: "DEFAULT"), .default)
        XCTAssertEqual(SplickColorTheme.from(storedValue: "unknown"), .default)
        XCTAssertEqual(SplickColorTheme.from(storedValue: nil), .default)
        XCTAssertNil(SplickColorTheme.default.alternateIconName(isDark: false))
        XCTAssertEqual(SplickColorTheme.default.alternateIconName(isDark: true), AppTheme.darkAlternateIconName)
    }
}
