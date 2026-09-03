import XCTest
@testable import Common

final class CompactCountTests: XCTestCase {
    func testExactThroughNineHundredNinetyNine() {
        XCTAssertEqual(CompactCount.format(1), "1")
        XCTAssertEqual(CompactCount.format(100), "100")
        XCTAssertEqual(CompactCount.format(999), "999")
    }

    func testThousandsAbbreviate() {
        XCTAssertEqual(CompactCount.format(1_000), "1k")
        XCTAssertEqual(CompactCount.format(1_500), "1.5k")
        XCTAssertEqual(CompactCount.format(100_000), "100k")
    }

    func testMillionsAbbreviate() {
        XCTAssertEqual(CompactCount.format(1_000_000), "1m")
        XCTAssertEqual(CompactCount.format(1_500_000), "1.5m")
    }
}
