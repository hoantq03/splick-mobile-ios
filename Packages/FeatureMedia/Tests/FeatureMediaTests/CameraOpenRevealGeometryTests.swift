import DesignSystem
import XCTest

final class CameraOpenRevealGeometryTests: XCTestCase {
    func testCoveringRadiusReachesFarthestCorner() {
        let origin = CGPoint(x: 50, y: 90)
        let radius = CameraOpenRevealGeometry.coveringRadius(
            origin: origin,
            size: CGSize(width: 100, height: 100)
        )
        XCTAssertEqual(radius, hypot(50, 90), accuracy: 0.01)
    }

    func testOriginSitsOnCameraButtonCenter() {
        let origin = CameraOpenRevealGeometry.origin(
            in: CGSize(width: 360, height: 800),
            cameraSize: 70,
            bottomInset: 10
        )
        XCTAssertEqual(origin.x, 180, accuracy: 0.01)
        XCTAssertEqual(origin.y, 800 - 10 - 35, accuracy: 0.01)
    }

    func testRadiusStartsAtButtonAndFillsScreen() {
        XCTAssertEqual(CameraOpenRevealGeometry.radius(progress: 0, start: 35, end: 400), 35, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.radius(progress: 1, start: 35, end: 400), 400, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.radius(progress: 0.5, start: 35, end: 400), 217.5, accuracy: 0.01)
    }

    func testFeatherSoftensMidSpreadAndClearsAtEnds() {
        XCTAssertEqual(CameraOpenRevealGeometry.feather(progress: 0, maxFeather: 48), 0, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.feather(progress: 0.5, maxFeather: 48), 48, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.feather(progress: 1, maxFeather: 48), 0, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.feather(progress: 0.25, maxFeather: 48), 36, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.maxFeatherFraction, 0.10, accuracy: 0.001)
        XCTAssertEqual(CameraOpenRevealGeometry.expandEase(0), 0, accuracy: 0.02)
        XCTAssertEqual(CameraOpenRevealGeometry.expandEase(1), 1, accuracy: 0.02)
        XCTAssertGreaterThan(CameraOpenRevealGeometry.expandEase(0.5), 0.35)
        XCTAssertLessThan(CameraOpenRevealGeometry.expandEase(0.5), 0.92)
    }

    func testShutterRowLiftsWithRevealProgress() {
        XCTAssertEqual(CameraOpenRevealGeometry.shutterRowLift(progress: 0), 0, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.shutterRowLift(progress: 1), CameraOpenRevealGeometry.shutterRestLift, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.shutterRowLift(progress: 0.7), CameraOpenRevealGeometry.shutterRestLift, accuracy: 0.01)
        XCTAssertEqual(CameraOpenRevealGeometry.shutterRowLift(progress: 0.35), CameraOpenRevealGeometry.shutterRestLift * 0.5, accuracy: 0.5)
    }

    func testShutterGrowsWithRevealProgress() {
        XCTAssertEqual(CameraOpenRevealGeometry.shutterOpenScale(progress: 0), 1, accuracy: 0.001)
        XCTAssertEqual(CameraOpenRevealGeometry.shutterOpenScale(progress: 0.7), CameraOpenRevealGeometry.shutterOpenedScale, accuracy: 0.001)
        XCTAssertEqual(CameraOpenRevealGeometry.shutterOpenScale(progress: 1), CameraOpenRevealGeometry.shutterOpenedScale, accuracy: 0.001)
        XCTAssertGreaterThan(CameraOpenRevealGeometry.shutterOpenScale(progress: 0.35), 1)
    }

    func testFinderSpreadStartsOnCameraButton() {
        let spread = CameraOpenRevealGeometry.finderSpread(
            progress: 0,
            cameraSize: 70,
            canvas: CGSize(width: 360, height: 800),
            bottomInset: 10,
            restWidth: 336,
            restHeight: 378,
            restCenter: CGPoint(x: 180, y: 360),
            restCorner: 22
        )
        XCTAssertEqual(spread.width, 70, accuracy: 0.01)
        XCTAssertEqual(spread.height, 70, accuracy: 0.01)
        XCTAssertEqual(spread.corner, 35, accuracy: 0.01)
        XCTAssertEqual(spread.center.x, 180, accuracy: 0.01)
        XCTAssertEqual(spread.center.y, 800 - 10 - 35, accuracy: 0.01)
    }

    func testFinderSpreadSettlesOnRestFrame() {
        let spread = CameraOpenRevealGeometry.finderSpread(
            progress: 1,
            cameraSize: 70,
            canvas: CGSize(width: 360, height: 800),
            bottomInset: 10,
            restWidth: 336,
            restHeight: 378,
            restCenter: CGPoint(x: 180, y: 360),
            restCorner: 22
        )
        XCTAssertEqual(spread.width, 336, accuracy: 0.01)
        XCTAssertEqual(spread.height, 378, accuracy: 0.01)
        XCTAssertEqual(spread.corner, 22, accuracy: 0.01)
        XCTAssertEqual(spread.center.x, 180, accuracy: 0.01)
        XCTAssertEqual(spread.center.y, 360, accuracy: 0.01)
    }

    func testFinderSpreadMidpointIsHalfway() {
        let spread = CameraOpenRevealGeometry.finderSpread(
            progress: 0.5,
            cameraSize: 70,
            canvas: CGSize(width: 360, height: 800),
            bottomInset: 10,
            restWidth: 336,
            restHeight: 378,
            restCenter: CGPoint(x: 180, y: 360),
            restCorner: 22
        )
        XCTAssertEqual(spread.width, 203, accuracy: 0.01)
        XCTAssertEqual(spread.height, 224, accuracy: 0.01)
        XCTAssertEqual(spread.corner, 28.5, accuracy: 0.01)
    }
}
