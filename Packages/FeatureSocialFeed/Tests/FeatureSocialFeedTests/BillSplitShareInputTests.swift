import XCTest
@testable import FeatureSocialFeed

final class BillSplitShareInputTests: XCTestCase {
    func testPercentClampsAbove100AndZerosRemaining() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let result = BillSplitShareInput.applyPercent(
            editedId: a,
            raw: "150",
            orderedIds: [a, b, c],
            current: [:],
            explicitIds: []
        )
        XCTAssertEqual(result.texts[a], "100")
        XCTAssertEqual(result.texts[b], "0")
        XCTAssertEqual(result.texts[c], "0")
    }

    func testPercentFillsOnlyTheRemainingUnenteredPerson() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let afterA = BillSplitShareInput.applyPercent(
            editedId: a,
            raw: "40",
            orderedIds: [a, b, c],
            current: [:],
            explicitIds: []
        )
        XCTAssertEqual(afterA.texts[a], "40")
        XCTAssertEqual(afterA.texts[b], "")
        XCTAssertEqual(afterA.texts[c], "")

        let afterB = BillSplitShareInput.applyPercent(
            editedId: b,
            raw: "25",
            orderedIds: [a, b, c],
            current: afterA.texts,
            explicitIds: afterA.explicitIds
        )
        XCTAssertEqual(afterB.texts[b], "25")
        XCTAssertEqual(afterB.texts[c], "35")

        let afterCAndA = BillSplitShareInput.applyPercent(
            editedId: c,
            raw: "10",
            orderedIds: [a, b, c],
            current: [:],
            explicitIds: []
        )
        let afterAThenC = BillSplitShareInput.applyPercent(
            editedId: a,
            raw: "40",
            orderedIds: [a, b, c],
            current: afterCAndA.texts,
            explicitIds: afterCAndA.explicitIds
        )
        XCTAssertEqual(afterAThenC.texts[a], "40")
        XCTAssertEqual(afterAThenC.texts[c], "10")
        XCTAssertEqual(afterAThenC.texts[b], "50")
    }

    func testPercentClampsWhenOthersAlreadyFill100() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let afterA = BillSplitShareInput.applyPercent(
            editedId: a,
            raw: "70",
            orderedIds: [a, b, c],
            current: [:],
            explicitIds: []
        )
        let afterB = BillSplitShareInput.applyPercent(
            editedId: b,
            raw: "50",
            orderedIds: [a, b, c],
            current: afterA.texts,
            explicitIds: afterA.explicitIds
        )
        XCTAssertEqual(afterB.texts[b], "30")
        XCTAssertEqual(afterB.texts[c], "0")
    }

    func testExactFillsRemainingPersonAndCapsAtTotal() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let total = Decimal(100_000)
        let afterA = BillSplitShareInput.applyExact(
            editedId: a,
            raw: "40000",
            orderedIds: [a, b, c],
            current: [:],
            explicitIds: [],
            total: total
        )
        XCTAssertEqual(VNDMoneyFormat.parse(afterA.texts[a] ?? ""), 40_000)
        XCTAssertEqual(afterA.texts[b], "")
        XCTAssertEqual(afterA.texts[c], "")

        let afterC = BillSplitShareInput.applyExact(
            editedId: c,
            raw: "25000",
            orderedIds: [a, b, c],
            current: afterA.texts,
            explicitIds: afterA.explicitIds,
            total: total
        )
        XCTAssertEqual(VNDMoneyFormat.parse(afterC.texts[c] ?? ""), 25_000)
        XCTAssertEqual(VNDMoneyFormat.parse(afterC.texts[b] ?? ""), 35_000)

        let overflow = BillSplitShareInput.applyExact(
            editedId: a,
            raw: "150000",
            orderedIds: [a, b],
            current: [:],
            explicitIds: [],
            total: total
        )
        XCTAssertEqual(VNDMoneyFormat.parse(overflow.texts[a] ?? ""), 100_000)
        XCTAssertEqual(VNDMoneyFormat.parse(overflow.texts[b] ?? ""), 0)
    }
}
