import CoreImage
import XCTest
@testable import FeatureMedia

final class FilterEngineTests: XCTestCase {
    func testNonePresetLeavesImageUnchanged() {
        let color = CIColor(red: 0.2, green: 0.4, blue: 0.6)
        let image = CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        let output = FilterEngine.apply(image, preset: .none, intensity: 1)
        XCTAssertEqual(output.extent, image.extent)
    }

    func testIdentityAdjustmentsAreNoOp() {
        let image = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let output = FilterEngine.applyAdjustments(image, .identity)
        XCTAssertEqual(output.extent, image.extent)
    }

    func testFadeCubeLoadsFromBundle() throws {
        let cube = try LUTCubeLoader.load(named: "fade")
        XCTAssertEqual(cube.size, 8)
        XCTAssertEqual(cube.data.count, 8 * 8 * 8 * 4 * MemoryLayout<Float>.size)
    }
}
