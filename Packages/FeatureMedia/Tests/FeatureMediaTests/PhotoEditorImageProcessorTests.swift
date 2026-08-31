import ImageIO
import UIKit
import XCTest
@testable import FeatureMedia

final class PhotoEditorImageProcessorTests: XCTestCase {
    func testCGImagePropertyOrientationSixMapsToRight() {
        XCTAssertEqual(
            PhotoEditorImageProcessor.uiImageOrientation(fromCGImagePropertyOrientationRaw: 6),
            .right
        )
        XCTAssertEqual(
            PhotoEditorImageProcessor.uiImageOrientation(fromCGImagePropertyOrientationRaw: 1),
            .up
        )
        XCTAssertEqual(
            PhotoEditorImageProcessor.uiImageOrientation(fromCGImagePropertyOrientationRaw: nil),
            .right
        )
    }

    func testPhotoMetadataOrientationIsAppliedBeforeNormalize() {
        let metadata: [String: Any] = [kCGImagePropertyOrientation as String: NSNumber(value: 6)]
        XCTAssertEqual(
            PhotoEditorImageProcessor.uiImageOrientation(fromPhotoMetadata: metadata),
            .right
        )
    }

    func testNormalizeOrientationKeepsPortraitSizeForRightEXIF() {
        let pixels = makeSolidImage(width: 40, height: 20, color: .red)
        let tagged = UIImage(cgImage: pixels.cgImage!, scale: 1, orientation: .right)
        XCTAssertEqual(tagged.size, CGSize(width: 20, height: 40))

        let normalized = PhotoEditorImageProcessor.normalizeOrientation(tagged)
        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertEqual(normalized.size.width, 20, accuracy: 0.5)
        XCTAssertEqual(normalized.size.height, 40, accuracy: 0.5)
    }

    func testCropToAspectFillCropsSidesOfWideImage() {
        let image = makeSolidImage(width: 400, height: 300, color: .blue)
        let cropped = PhotoEditorImageProcessor.cropToAspectFill(image, aspectRatio: 1080 / 2340)
        XCTAssertEqual(cropped.size.height, 300, accuracy: 1)
        XCTAssertEqual(cropped.size.width, 300 * (1080 / 2340), accuracy: 2)
    }

    private func makeSolidImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
