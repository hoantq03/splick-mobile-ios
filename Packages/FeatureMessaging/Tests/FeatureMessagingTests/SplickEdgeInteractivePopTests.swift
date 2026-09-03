import XCTest
import DesignSystem

final class SplickEdgeInteractivePopTests: XCTestCase {

    func testLeadingBandIsFlushToThePhysicalEdge() {
        XCTAssertTrue(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 0, viewWidth: 390, isRightToLeft: false)
        )
        XCTAssertTrue(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 12, viewWidth: 390, isRightToLeft: false)
        )
        XCTAssertFalse(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 13, viewWidth: 390, isRightToLeft: false)
        )
        XCTAssertFalse(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 40, viewWidth: 390, isRightToLeft: false)
        )
    }

    func testTrailingBandForRightToLeft() {
        XCTAssertTrue(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 390, viewWidth: 390, isRightToLeft: true)
        )
        XCTAssertFalse(
            SplickEdgeInteractivePop.isInLeadingEdgeBand(x: 0, viewWidth: 390, isRightToLeft: true)
        )
    }

    func testHorizontalDominantPopRejectsVerticalPull() {
        XCTAssertFalse(
            SplickInteractivePopAxis.isOutwardHorizontalPop(
                translation: CGPoint(x: 4, y: -28),
                isRightToLeft: false
            )
        )
        XCTAssertTrue(
            SplickInteractivePopAxis.isOutwardHorizontalPop(
                translation: CGPoint(x: 24, y: 6),
                isRightToLeft: false
            )
        )
    }
}
