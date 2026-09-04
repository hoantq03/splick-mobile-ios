import CoreImage
import UIKit
import Vision

/// Applies LUT color grades, parametric looks, and optional beauty to a `CIImage`.
enum FilterEngine {
    static func apply(
        _ image: CIImage,
        preset: FilterPreset,
        intensity: Float = 1
    ) -> CIImage {
        let amount = min(max(intensity, 0), 1)
        switch preset {
        case .none:
            return image
        case .cinematic, .vintage, .vivid, .fade:
            guard let name = preset.cubeResourceName else { return image }
            return LUTFilterProcessor.apply(image, cubeName: name, intensity: amount)
        case .blackAndWhite:
            return mix(original: image, filtered: mono(image), intensity: amount)
        case .warm:
            return mix(original: image, filtered: temperature(image, value: 0.35), intensity: amount)
        case .cool:
            return mix(original: image, filtered: temperature(image, value: -0.35), intensity: amount)
        }
    }

    static func apply(
        _ image: CIImage,
        cameraPreset: CameraFilterPreset,
        intensity: Float,
        faceObservations: [VNFaceObservation]
    ) -> CIImage {
        switch cameraPreset {
        case .none, .ar:
            return image
        case .beauty:
            return BeautyFilterGroup.apply(image, intensity: intensity, faceObservations: faceObservations)
        case .cinematic, .vintage, .vivid, .fade, .blackAndWhite, .warm, .cool:
            return apply(image, preset: FilterPreset(cameraPreset), intensity: intensity)
        }
    }

    static func applyAdjustments(_ image: CIImage, _ adjustments: ImageAdjustments) -> CIImage {
        guard !adjustments.isIdentity else { return image }
        var current = image
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(current, forKey: kCIInputImageKey)
            controls.setValue(adjustments.brightness, forKey: kCIInputBrightnessKey)
            controls.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
            controls.setValue(adjustments.saturation, forKey: kCIInputSaturationKey)
            current = controls.outputImage ?? current
        }
        if abs(adjustments.exposure) > 0.001, let exposure = CIFilter(name: "CIExposureAdjust") {
            exposure.setValue(current, forKey: kCIInputImageKey)
            exposure.setValue(adjustments.exposure, forKey: kCIInputEVKey)
            current = exposure.outputImage ?? current
        }
        return current
    }

    static func renderUIImage(from image: CIImage, context: CIContext = MediaRenderContext.ciContext) -> UIImage? {
        let extent = image.extent.integral
        guard extent.width > 1, extent.height > 1,
              let cg = context.createCGImage(image, from: extent)
        else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func mono(_ image: CIImage) -> CIImage {
        if let filter = CIFilter(name: "CIPhotoEffectMono") {
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage ?? image
        }
        guard let controls = CIFilter(name: "CIColorControls") else { return image }
        controls.setValue(image, forKey: kCIInputImageKey)
        controls.setValue(0, forKey: kCIInputSaturationKey)
        return controls.outputImage ?? image
    }

    private static func temperature(_ image: CIImage, value: CGFloat) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 6500 + value * 2500, y: 0), forKey: "inputNeutral")
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
        return filter.outputImage ?? image
    }

    private static func mix(original: CIImage, filtered: CIImage, intensity: Float) -> CIImage {
        LUTFilterProcessor.mix(original: original, filtered: filtered, intensity: intensity)
    }
}
