import XCTest
import SplickDomain

final class VndAmountRulesTests: XCTestCase {
    func test_minimumAmount_is1000() {
        XCTAssertEqual(VndAmountRules.minimumAmount, 1_000)
    }

    func test_isAtLeastMinimum_rejectsBelowFloor() {
        XCTAssertFalse(VndAmountRules.isAtLeastMinimum(0))
        XCTAssertFalse(VndAmountRules.isAtLeastMinimum(1))
        XCTAssertFalse(VndAmountRules.isAtLeastMinimum(999))
    }

    func test_isAtLeastMinimum_acceptsFloorAndAbove() {
        XCTAssertTrue(VndAmountRules.isAtLeastMinimum(1_000))
        XCTAssertTrue(VndAmountRules.isAtLeastMinimum(1_001))
        XCTAssertTrue(VndAmountRules.isAtLeastMinimum(50_000))
    }
}
