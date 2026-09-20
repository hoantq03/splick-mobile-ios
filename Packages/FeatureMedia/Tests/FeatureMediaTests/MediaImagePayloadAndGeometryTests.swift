import XCTest
import UIKit
@testable import FeatureMedia

final class MediaImagePayloadAndGeometryTests: XCTestCase {
    private func createTestImage(width: CGFloat, height: CGFloat, color: UIColor = .blue) -> UIImage {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    func testJpegAvatarDataSuccess() throws {
        let image = createTestImage(width: 100, height: 100)
        let payload = try MediaImagePayload.jpegAvatarData(from: image)
        XCTAssertFalse(payload.data.isEmpty)
        XCTAssertEqual(payload.mimeType, "image/jpeg")
    }

    func testDownsampledRespectsMaxSide() {
        let largeImage = createTestImage(width: 2000, height: 1000)
        let downsampled = MediaImagePayload.downsampled(largeImage, maxSide: 500)
        XCTAssertEqual(downsampled.size.width, 500, accuracy: 1.0)
        XCTAssertEqual(downsampled.size.height, 250, accuracy: 1.0)

        // When image is smaller than maxSide, it returns original image unmodified
        let smallImage = createTestImage(width: 300, height: 200)
        let notDownsampled = MediaImagePayload.downsampled(smallImage, maxSide: 500)
        XCTAssertEqual(notDownsampled.size.width, 300)
        XCTAssertEqual(notDownsampled.size.height, 200)
    }

    func testJpegUploadData() throws {
        let image = createTestImage(width: 800, height: 600)
        let data = try MediaImagePayload.jpegUploadData(
            from: image,
            maxSide: 640,
            maxBytes: 500_000,
            compressionQuality: 0.8
        )
        XCTAssertFalse(data.isEmpty)
        XCTAssertLessThanOrEqual(data.count, 500_000)
    }

    func testCropAspectPresetProperties() {
        XCTAssertNil(CropAspectPreset.original.pixelAspect)
        XCTAssertNil(CropAspectPreset.original.ratioLabel)
        XCTAssertNil(CropAspectPreset.free.pixelAspect)
        XCTAssertNil(CropAspectPreset.free.ratioLabel)

        XCTAssertEqual(CropAspectPreset.square.pixelAspect, 1.0)
        XCTAssertEqual(CropAspectPreset.square.ratioLabel, "1:1")

        XCTAssertEqual(CropAspectPreset.portrait4x5.pixelAspect, 4.0 / 5.0)
        XCTAssertEqual(CropAspectPreset.portrait4x5.ratioLabel, "4:5")

        XCTAssertEqual(CropAspectPreset.portrait3x4.pixelAspect, 3.0 / 4.0)
        XCTAssertEqual(CropAspectPreset.portrait3x4.ratioLabel, "3:4")

        XCTAssertEqual(CropAspectPreset.story9x16.pixelAspect, 9.0 / 16.0)
        XCTAssertEqual(CropAspectPreset.story9x16.ratioLabel, "9:16")

        XCTAssertEqual(CropAspectPreset.landscape16x9.pixelAspect, 16.0 / 9.0)
        XCTAssertEqual(CropAspectPreset.landscape16x9.ratioLabel, "16:9")

        XCTAssertEqual(CropAspectPreset.landscape4x3.pixelAspect, 4.0 / 3.0)
        XCTAssertEqual(CropAspectPreset.landscape4x3.ratioLabel, "4:3")

        XCTAssertEqual(CropAspectPreset.square.id, "square")
        XCTAssertEqual(CropAspectPreset.allCases.count, 8)
    }

    func testCropGeometryNormalizedAspect() {
        // Zero size fallback
        let zeroResult = CropGeometry.normalizedAspect(pixelAspect: 1.5, imageSize: .zero)
        XCTAssertEqual(zeroResult, 1.5)

        // Non-zero calculation: pixelAspect * height / width
        let aspect = CropGeometry.normalizedAspect(pixelAspect: 2.0, imageSize: CGSize(width: 400, height: 200))
        XCTAssertEqual(aspect, 1.0) // 2.0 * 200 / 400 = 1.0
    }

    func testCropGeometryFittedRect() {
        let center = CGPoint(x: 0.5, y: 0.5)

        // aspect >= 1 (e.g. 2.0 -> width 1.0, height 0.5)
        let rectWide = CropGeometry.fittedRect(normalizedAspect: 2.0, center: center)
        XCTAssertEqual(rectWide.width, 1.0)
        XCTAssertEqual(rectWide.height, 0.5)
        XCTAssertEqual(rectWide.origin.x, 0.0)
        XCTAssertEqual(rectWide.origin.y, 0.25)

        // aspect < 1 (e.g. 0.5 -> height 1.0, width 0.5)
        let rectTall = CropGeometry.fittedRect(normalizedAspect: 0.5, center: center)
        XCTAssertEqual(rectTall.width, 0.5)
        XCTAssertEqual(rectTall.height, 1.0)
        XCTAssertEqual(rectTall.origin.x, 0.25)
        XCTAssertEqual(rectTall.origin.y, 0.0)
    }

    func testCropGeometryClamp() {
        // Out of bounds rect
        let outRect = CGRect(x: -0.5, y: 1.5, width: 2.0, height: 0.01)
        let clamped = CropGeometry.clamp(outRect)

        XCTAssertGreaterThanOrEqual(clamped.origin.x, 0.0)
        XCTAssertGreaterThanOrEqual(clamped.origin.y, 0.0)
        XCTAssertLessThanOrEqual(clamped.maxX, 1.0)
        XCTAssertLessThanOrEqual(clamped.maxY, 1.0)
        XCTAssertGreaterThanOrEqual(clamped.width, CropGeometry.minNormalizedSize)
        XCTAssertGreaterThanOrEqual(clamped.height, CropGeometry.minNormalizedSize)

        let locked = CropGeometry.clampLocked(CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), normalizedAspect: 1.0)
        XCTAssertEqual(locked.width, 1.0)
        XCTAssertEqual(locked.height, 1.0)
        XCTAssertEqual(locked.origin.x, 0.0)
        XCTAssertEqual(locked.origin.y, 0.0)
    }
}

final class CameraZoomAndFocusTests: XCTestCase {
    func testCameraZoomHardwareCalculations() {
        let hw = CameraZoom.hardware(
            minVideo: 1.0,
            maxVideo: 10.0,
            switchOverVideo: [2.0],
            systemDisplayMultiplier: 0.5
        )

        XCTAssertEqual(hw.minDisplay, 0.5)
        XCTAssertEqual(hw.maxDisplay, 5.0)
        XCTAssertEqual(hw.display(fromVideo: 2.0), 1.0)
        XCTAssertEqual(hw.video(fromDisplay: 1.0), 2.0)

        // Presets & Tap Stops
        let presets = hw.presets
        XCTAssertFalse(presets.isEmpty)
        XCTAssertTrue(presets.contains(1.0))

        let stops = CameraZoom.tapStops(for: hw)
        XCTAssertTrue(stops.contains(1.0))

        // Clamping & Pinch
        XCTAssertEqual(CameraZoom.clampDisplay(0.1, hardware: hw), 0.5)
        XCTAssertEqual(CameraZoom.clampDisplay(10.0, hardware: hw), 5.0)
        XCTAssertEqual(CameraZoom.applyPinch(base: 1.0, scale: 2.0, hardware: hw), 2.0)

        // Labels
        XCTAssertEqual(CameraZoom.label(1.0), "1×")
        XCTAssertEqual(CameraZoom.label(2.5), "2.5×")
        XCTAssertEqual(CameraZoom.pillLabel(1.0, isSelected: true, currentDisplay: 1.8), "1.8×")
        XCTAssertEqual(CameraZoom.pillLabel(1.0, isSelected: false, currentDisplay: 1.8), "1×")

        // Dial progress
        let progress = CameraZoom.dialProgress(display: 1.0, hardware: hw)
        XCTAssertGreaterThan(progress, 0.0)
        XCTAssertLessThan(progress, 1.0)
    }

    func testCameraFocusMapping() {
        let viewSize = CGSize(width: 300, height: 600)

        // Center tap non-mirrored
        let center = CGPoint(x: 150, y: 300)
        let poiCenter = CameraFocusMapping.devicePointOfInterest(
            viewPoint: center,
            viewSize: viewSize,
            mirrored: false
        )
        XCTAssertEqual(poiCenter.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(poiCenter.y, 0.5, accuracy: 0.01)

        // Mirrored (front camera)
        let poiMirrored = CameraFocusMapping.devicePointOfInterest(
            viewPoint: center,
            viewSize: viewSize,
            mirrored: true
        )
        XCTAssertEqual(poiMirrored.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(poiMirrored.y, 0.5, accuracy: 0.01)

        // Zero size fallback
        let poiZero = CameraFocusMapping.devicePointOfInterest(
            viewPoint: center,
            viewSize: .zero,
            mirrored: false
        )
        XCTAssertEqual(poiZero, CGPoint(x: 0.5, y: 0.5))

        // Focus indicator token
        let indicator1 = CameraFocusIndicator(point: center)
        let indicator2 = CameraFocusIndicator(point: center)
        XCTAssertNotEqual(indicator1.token, indicator2.token)
        XCTAssertEqual(indicator1.point, indicator2.point)
    }
}
