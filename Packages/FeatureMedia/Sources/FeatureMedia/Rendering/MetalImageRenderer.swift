import CoreImage
import PencilKit
import UIKit

actor MetalImageRenderer {
    func renderPreview(
        _ state: EditState,
        from original: CIImage,
        maxDimension: CGFloat,
        ignoreCrop: Bool
    ) async -> UIImage? {
        var image = pipeline(state, from: original, ignoreCrop: ignoreCrop)
        image = scaled(image, maxDimension: maxDimension)
        return FilterEngine.renderUIImage(from: image)
    }

    func renderBase(
        _ state: EditState,
        from original: CIImage,
        ignoreCrop: Bool = false
    ) async -> UIImage? {
        let image = pipeline(state, from: original, ignoreCrop: ignoreCrop)
        return FilterEngine.renderUIImage(from: image)
    }

    private func pipeline(_ state: EditState, from original: CIImage, ignoreCrop: Bool) -> CIImage {
        var image = FilterEngine.apply(original, preset: state.activeFilter, intensity: 1)
        image = FilterEngine.applyAdjustments(image, state.adjustments)
        image = rotated(image, quarters: state.normalizedRotation)
        if !ignoreCrop, state.isEffectiveCrop {
            image = cropped(image, normalized: state.cropRect)
        }
        return image
    }

    private func rotated(_ image: CIImage, quarters: Int) -> CIImage {
        switch quarters {
        case 1: return image.oriented(.right)
        case 2: return image.oriented(.down)
        case 3: return image.oriented(.left)
        default: return image
        }
    }

    private func cropped(_ image: CIImage, normalized: CGRect) -> CIImage {
        let extent = image.extent
        let rect = CGRect(
            x: extent.minX + normalized.minX * extent.width,
            y: extent.minY + (1 - normalized.maxY) * extent.height,
            width: normalized.width * extent.width,
            height: normalized.height * extent.height
        ).integral
        guard rect.width > 1, rect.height > 1 else { return image }
        return image.cropped(to: rect)
    }

    private func scaled(_ image: CIImage, maxDimension: CGFloat) -> CIImage {
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}
