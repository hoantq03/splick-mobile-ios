import XCTest
@testable import FeatureMedia

final class CameraZoomTests: XCTestCase {
    func testPinchScalesFromBaseAndClampsToUxMax() {
        XCTAssertEqual(CameraZoom.applyPinch(base: 1, scale: 2, min: 1, max: 10), 2, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.applyPinch(base: 4, scale: 4, min: 1, max: 15), 10, accuracy: 0.001)
    }

    func testTapCyclesPresetStopsAndWraps() {
        XCTAssertEqual(CameraZoom.nextStep(current: 1, min: 1, max: 10), 2, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextStep(current: 2, min: 1, max: 10), 4, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextStep(current: 4, min: 1, max: 10), 5, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextStep(current: 5, min: 1, max: 10), 8, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextStep(current: 8, min: 1, max: 10), 10, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextStep(current: 10, min: 1, max: 10), 1, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextStep(current: 8, min: 1, max: 8), 1, accuracy: 0.001)
    }

    func testPanRightZoomsInAndLeftZoomsOut() {
        let wider = CameraZoom.applyPan(base: 2, deltaPx: 200, viewWidth: 400, min: 1, max: 10)
        let narrower = CameraZoom.applyPan(base: 2, deltaPx: -200, viewWidth: 400, min: 1, max: 10)
        XCTAssertEqual(wider, 6.5, accuracy: 0.05)
        XCTAssertEqual(narrower, 1, accuracy: 0.05)
    }

    func testLabelUsesTimesSign() {
        XCTAssertEqual(CameraZoom.label(1), "1×")
        XCTAssertEqual(CameraZoom.label(2.02), "2×")
        XCTAssertEqual(CameraZoom.label(2.41), "2.4×")
    }
}
