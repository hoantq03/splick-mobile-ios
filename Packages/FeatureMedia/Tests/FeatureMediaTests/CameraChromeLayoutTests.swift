import UIKit
import XCTest
@testable import FeatureMedia

final class CameraChromeLayoutTests: XCTestCase {
    func testToolsFitIPhoneSEWidth() {
        let width: CGFloat = 320
        let column = CameraChromeLayout.toolColumnWidth(containerWidth: width)
        XCTAssertEqual(column * CameraChromeLayout.toolCount, CameraChromeLayout.toolsRowWidth(containerWidth: width), accuracy: 0.01)
        XCTAssertLessThanOrEqual(column * 4, width)
    }

    func testCompactPhoneShrinksShutterAndLift() {
        let se = CameraChromeLayout.metrics(
            in: CGSize(width: 375, height: 667),
            safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        )
        let pro = CameraChromeLayout.metrics(
            in: CGSize(width: 430, height: 932),
            safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        )
        XCTAssertLessThan(se.shutterDiameter, pro.shutterDiameter)
        XCTAssertLessThan(se.previewLift, pro.previewLift)
        XCTAssertLessThan(se.toolIconSize, pro.toolIconSize)
        XCTAssertGreaterThanOrEqual(se.bottomPadding, 8)
        XCTAssertGreaterThanOrEqual(se.topPadding, 20)
        XCTAssertEqual(pro.bottomPadding, 46, accuracy: 0.01)
    }

    func testHomeIndicatorIsReservedInBottomPadding() {
        let metrics = CameraChromeLayout.metrics(
            in: CGSize(width: 375, height: 812),
            safeArea: UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)
        )
        XCTAssertGreaterThanOrEqual(metrics.bottomPadding, 34)
    }
}
