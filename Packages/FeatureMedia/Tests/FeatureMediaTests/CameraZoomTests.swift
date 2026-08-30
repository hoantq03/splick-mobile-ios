import XCTest
@testable import FeatureMedia

final class CameraZoomTests: XCTestCase {
    func testTripleCameraMapsUltraWideWideAndTele() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 16, switchOverVideo: [2, 6])
        XCTAssertEqual(hw.displayMultiplier, 0.5, accuracy: 0.001)
        XCTAssertEqual(hw.display(fromVideo: 1), 0.5, accuracy: 0.01)
        XCTAssertEqual(hw.display(fromVideo: 2), 1, accuracy: 0.01)
        XCTAssertEqual(hw.display(fromVideo: 6), 3, accuracy: 0.01)
        XCTAssertEqual(hw.video(fromDisplay: 1), 2, accuracy: 0.01)
        XCTAssertEqual(hw.presets, [0.5, 1, 2, 3])
    }

    func testDualWidePresetsIncludeHalfAndTwo() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 10, switchOverVideo: [2])
        XCTAssertEqual(hw.presets, [0.5, 1, 2])
    }

    func testProFiveXTeleAddsTwoCrop() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 25, switchOverVideo: [2, 10])
        XCTAssertEqual(hw.presets, [0.5, 1, 2, 5])
    }

    func testWideOnlyStartsAtOneX() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 8, switchOverVideo: [])
        XCTAssertEqual(hw.minDisplay, 1, accuracy: 0.01)
        XCTAssertEqual(hw.presets, [1, 2])
    }

    func testSystemMultiplierWinsOverSwitchOverHeuristic() {
        let hw = CameraZoom.hardware(
            minVideo: 1,
            maxVideo: 16,
            switchOverVideo: [2, 6],
            systemDisplayMultiplier: 0.5
        )
        XCTAssertEqual(hw.displayMultiplier, 0.5, accuracy: 0.001)
    }

    func testPinchScalesFromBaseAndClampsToUxMax() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 20, switchOverVideo: [])
        XCTAssertEqual(CameraZoom.applyPinch(base: 1, scale: 2, hardware: hw), 2, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.applyPinch(base: 4, scale: 8, hardware: hw), 15, accuracy: 0.001)
    }

    func testPinchCanReachUltraWide() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 10, switchOverVideo: [2])
        XCTAssertEqual(CameraZoom.applyPinch(base: 1, scale: 0.4, hardware: hw), 0.5, accuracy: 0.05)
    }

    func testTapCyclesDevicePresets() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 16, switchOverVideo: [2, 6])
        XCTAssertEqual(CameraZoom.nextPreset(current: 0.5, hardware: hw), 1, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextPreset(current: 1, hardware: hw), 2, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextPreset(current: 2, hardware: hw), 3, accuracy: 0.001)
        XCTAssertEqual(CameraZoom.nextPreset(current: 3, hardware: hw), 0.5, accuracy: 0.001)
    }

    func testPanRightZoomsInAndLeftZoomsOutOnLogScale() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 10, switchOverVideo: [])
        let wider = CameraZoom.applyPan(base: 2, deltaPx: 200, viewWidth: 400, hardware: hw)
        let narrower = CameraZoom.applyPan(base: 2, deltaPx: -200, viewWidth: 400, hardware: hw)
        XCTAssertGreaterThan(wider, 2)
        XCTAssertLessThan(narrower, 2)
        XCTAssertEqual(narrower, 1, accuracy: 0.05)
    }

    func testDialProgressIsZeroAtMinAndOneAtMax() {
        let hw = CameraZoom.hardware(minVideo: 1, maxVideo: 10, switchOverVideo: [2])
        XCTAssertEqual(CameraZoom.dialProgress(display: hw.minDisplay, hardware: hw), 0, accuracy: 0.01)
        XCTAssertEqual(CameraZoom.dialProgress(display: hw.maxDisplay, hardware: hw), 1, accuracy: 0.01)
    }

    func testFocusPointOfInterestMapsPortraitTapToSensorSpace() {
        let back = CameraFocusMapping.devicePointOfInterest(
            viewPoint: CGPoint(x: 25, y: 50),
            viewSize: CGSize(width: 100, height: 100),
            mirrored: false
        )
        XCTAssertEqual(back.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(back.y, 0.75, accuracy: 0.01)

        let front = CameraFocusMapping.devicePointOfInterest(
            viewPoint: CGPoint(x: 25, y: 50),
            viewSize: CGSize(width: 100, height: 100),
            mirrored: true
        )
        XCTAssertEqual(front.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(front.y, 0.25, accuracy: 0.01)
    }

    func testLabelUsesTimesSign() {
        XCTAssertEqual(CameraZoom.label(1), "1×")
        XCTAssertEqual(CameraZoom.label(0.5), "0.5×")
        XCTAssertEqual(CameraZoom.label(2.02), "2×")
        XCTAssertEqual(CameraZoom.label(2.41), "2.4×")
    }
}
