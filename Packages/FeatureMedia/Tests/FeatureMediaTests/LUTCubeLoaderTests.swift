import XCTest
@testable import FeatureMedia

final class LUTCubeLoaderTests: XCTestCase {
    func testParsesIdentityCube() throws {
        let cube = """
        TITLE "Identity"
        LUT_3D_SIZE 2
        DOMAIN_MIN 0.0 0.0 0.0
        DOMAIN_MAX 1.0 1.0 1.0
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1
        """
        let parsed = try LUTCubeLoader.parse(cube)
        XCTAssertEqual(parsed.size, 2)
        XCTAssertEqual(parsed.data.count, 2 * 2 * 2 * 4 * MemoryLayout<Float>.size)
    }

    func testRejectsBadSize() {
        XCTAssertThrowsError(try LUTCubeLoader.parse("LUT_3D_SIZE 0\n"))
    }
}
