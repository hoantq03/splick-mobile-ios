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

    func testMatchSelfieFinderMirrorsFrontCameraOnly() {
        let image = makeLeftRedRightBlueImage()
        let left = pixel(at: CGPoint(x: 0, y: 0), in: image)
        let right = pixel(at: CGPoint(x: 1, y: 0), in: image)
        XCTAssertNotEqual(left.0, right.0)

        let back = PhotoEditorImageProcessor.matchSelfieFinder(image, isFrontCamera: false)
        XCTAssertEqual(pixel(at: CGPoint(x: 0, y: 0), in: back).0, left.0)
        XCTAssertEqual(pixel(at: CGPoint(x: 1, y: 0), in: back).0, right.0)

        let front = PhotoEditorImageProcessor.matchSelfieFinder(image, isFrontCamera: true)
        XCTAssertEqual(pixel(at: CGPoint(x: 0, y: 0), in: front).0, right.0)
        XCTAssertEqual(pixel(at: CGPoint(x: 1, y: 0), in: front).0, left.0)
        XCTAssertEqual(front.size, image.size)
        XCTAssertEqual(front.imageOrientation, .up)
    }

    func testCropToAspectFillCropsSidesOfWideImage() {
        let image = makeSolidImage(width: 400, height: 300, color: .blue)
        let cropped = PhotoEditorImageProcessor.cropToAspectFill(image, aspectRatio: 1080 / 2340)
        XCTAssertEqual(cropped.size.height, 300, accuracy: 1)
        XCTAssertEqual(cropped.size.width, 300 * (1080 / 2340), accuracy: 2)
    }

    private func makeLeftRedRightBlueImage() -> UIImage {
        let size = CGSize(width: 2, height: 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        }
    }

    private func pixel(at point: CGPoint, in image: UIImage) -> (UInt8, UInt8, UInt8) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let sample = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in
            image.draw(at: CGPoint(x: -point.x, y: -point.y))
        }
        guard let data = sample.cgImage?.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else {
            return (0, 0, 0)
        }
        let info = sample.cgImage!.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: info.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)
        let isBGRA = info.contains(.byteOrder32Little) || alphaInfo == .premultipliedFirst || alphaInfo == .noneSkipFirst
        if isBGRA {
            return (ptr[2], ptr[1], ptr[0])
        }
        return (ptr[0], ptr[1], ptr[2])
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
