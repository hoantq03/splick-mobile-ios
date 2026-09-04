import CoreImage
import Vision

/// Skin smooth + subtle face slim using Core Image and Vision (no paid SDK).
/// Harbeth-style composition: chain independently tunable CI filters.
enum BeautyFilterGroup {
    static func apply(
        _ image: CIImage,
        intensity: Float,
        faceObservations: [VNFaceObservation]
    ) -> CIImage {
        let amount = min(max(intensity, 0), 1)
        guard amount > 0.01 else { return image }

        var current = image
        current = smoothSkin(current, intensity: amount)
        current = liftShadows(current, intensity: amount)
        if let face = faceObservations.max(by: { $0.boundingBox.width * $0.boundingBox.height
            < $1.boundingBox.width * $1.boundingBox.height }) {
            current = slimFace(current, face: face, intensity: amount)
        }
        return current
    }

    private static func smoothSkin(_ image: CIImage, intensity: Float) -> CIImage {
        let radius = CGFloat(1.2 + Double(intensity) * 4.5)
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return image }
        blur.setValue(image, forKey: kCIInputImageKey)
        blur.setValue(radius, forKey: kCIInputRadiusKey)
        guard let blurred = blur.outputImage?.cropped(to: image.extent) else { return image }

        guard let blend = CIFilter(name: "CIDissolveTransition") else { return image }
        blend.setValue(image, forKey: kCIInputImageKey)
        blend.setValue(blurred, forKey: kCIInputTargetImageKey)
        blend.setValue(0.18 + intensity * 0.28, forKey: kCIInputTimeKey)
        return blend.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func liftShadows(_ image: CIImage, intensity: Float) -> CIImage {
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(intensity * 0.45, forKey: "inputShadowAmount")
        filter.setValue(1 - intensity * 0.12, forKey: "inputHighlightAmount")
        return filter.outputImage ?? image
    }

    private static func slimFace(_ image: CIImage, face: VNFaceObservation, intensity: Float) -> CIImage {
        let extent = image.extent
        guard extent.width > 1, extent.height > 1 else { return image }
        let box = face.boundingBox
        let center = CGPoint(
            x: extent.minX + box.midX * extent.width,
            y: extent.minY + box.midY * extent.height
        )
        let radius = min(extent.width, extent.height) * CGFloat(box.width) * 0.85
        guard let bump = CIFilter(name: "CIBumpDistortion") else { return image }
        bump.setValue(image, forKey: kCIInputImageKey)
        bump.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
        bump.setValue(radius, forKey: kCIInputRadiusKey)
        bump.setValue(-0.18 * CGFloat(intensity), forKey: kCIInputScaleKey)
        return bump.outputImage?.cropped(to: extent) ?? image
    }
}
