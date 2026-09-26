import UIKit
import XCTest
import DesignSystem
@testable import FeatureStickers

final class CustomEmojiCropRendererTests: XCTestCase {
    func testAspectFitKeepsWideImageRatio() {
        let fitted = ImageCropRenderer.aspectFit(
            imageSize: CGSize(width: 40, height: 20),
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertEqual(fitted.width, 100, accuracy: 0.01)
        XCTAssertEqual(fitted.height, 50, accuracy: 0.01)
    }

    func testRenderDoesNotSquashWideImageIntoSquareViewport() {
        let source = makeSolidImage(width: 40, height: 20, color: .red)
        let rendered = ImageCropRenderer.render(
            source: source,
            transform: fullViewportTransform(),
            outputSize: 100
        )
        XCTAssertEqual(rendered.size, CGSize(width: 100, height: 100))

        let center = pixel(in: rendered, x: 50, y: 50)
        let top = pixel(in: rendered, x: 50, y: 8)
        XCTAssertGreaterThan(center.red, 0.8)
        XCTAssertLessThan(top.alpha, 0.15)
    }

    func testRenderUsesOrientedSizeSoPortraitEXIFIsNotSquashed() {
        let landscapePixels = makeSolidImage(width: 40, height: 20, color: .red)
        let tagged = UIImage(cgImage: landscapePixels.cgImage!, scale: 1, orientation: .right)
        XCTAssertEqual(tagged.size, CGSize(width: 20, height: 40))

        let rendered = ImageCropRenderer.render(
            source: tagged,
            transform: fullViewportTransform(),
            outputSize: 100
        )

        let center = pixel(in: rendered, x: 50, y: 50)
        let left = pixel(in: rendered, x: 8, y: 50)
        XCTAssertGreaterThan(center.red, 0.8)
        XCTAssertLessThan(left.alpha, 0.15)
    }

    func testPrepareUploadDataEmitsSquareJPEGWithoutStretchingPortrait() {
        let landscapePixels = makeSolidImage(width: 40, height: 20, color: .blue)
        let tagged = UIImage(cgImage: landscapePixels.cgImage!, scale: 1, orientation: .right)
        let (data, mime) = try! CustomEmojiImageProcessor.prepareUploadData(from: tagged)
        XCTAssertEqual(mime, "image/jpeg")
        let uploaded = UIImage(data: data)!
        XCTAssertEqual(uploaded.size.width, CustomEmojiImageProcessor.targetSize.width, accuracy: 0.5)
        XCTAssertEqual(uploaded.size.height, CustomEmojiImageProcessor.targetSize.height, accuracy: 0.5)
    }

    private func fullViewportTransform() -> ImageCropTransform {
        ImageCropTransform(
            viewportSize: CGSize(width: 100, height: 100),
            imageScale: 1,
            offset: .zero,
            rotationDegrees: 0,
            flipHorizontal: false,
            crop: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
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

    private func pixel(in image: UIImage, x: Int, y: Int) -> (red: CGFloat, alpha: CGFloat) {
        guard let cgImage = image.cgImage else { return (0, 0) }
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.translateBy(x: CGFloat(-x), y: CGFloat(-y))
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return (CGFloat(pixel[0]) / 255, CGFloat(pixel[3]) / 255)
    }
}
