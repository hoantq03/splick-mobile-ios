import CoreGraphics
import Localization

/// Popular crop ratios. `pixelAspect` is width / height in image pixels; `nil` means unlocked.
enum CropAspectPreset: String, CaseIterable, Identifiable, Equatable {
    case original
    case free
    case square
    case portrait4x5
    case portrait3x4
    case story9x16
    case landscape16x9
    case landscape4x3

    var id: String { rawValue }

    var pixelAspect: CGFloat? {
        switch self {
        case .original, .free: return nil
        case .square: return 1
        case .portrait4x5: return 4 / 5
        case .portrait3x4: return 3 / 4
        case .story9x16: return 9 / 16
        case .landscape16x9: return 16 / 9
        case .landscape4x3: return 4 / 3
        }
    }

    var ratioLabel: String? {
        switch self {
        case .original, .free: return nil
        case .square: return "1:1"
        case .portrait4x5: return "4:5"
        case .portrait3x4: return "3:4"
        case .story9x16: return "9:16"
        case .landscape16x9: return "16:9"
        case .landscape4x3: return "4:3"
        }
    }

    @MainActor
    func title(using languageService: LanguageService) -> String {
        switch self {
        case .original: return languageService.text(.mediaCropOriginal)
        case .free: return languageService.text(.mediaCropFree)
        default: return ratioLabel ?? rawValue
        }
    }
}

enum CropGeometry {
    static let minNormalizedSize: CGFloat = 0.08

    /// Normalized width/height that matches `pixelAspect` on an image of `imageSize`.
    static func normalizedAspect(pixelAspect: CGFloat, imageSize: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return pixelAspect }
        return pixelAspect * imageSize.height / imageSize.width
    }

    /// Largest rect of the given normalized aspect, centered on `center` inside the unit square.
    static func fittedRect(normalizedAspect: CGFloat, center: CGPoint) -> CGRect {
        let aspect = max(normalizedAspect, 0.01)
        var width: CGFloat
        var height: CGFloat
        if aspect >= 1 {
            width = 1
            height = width / aspect
        } else {
            height = 1
            width = height * aspect
        }
        if height > 1 {
            height = 1
            width = height * aspect
        }
        if width > 1 {
            width = 1
            height = width / aspect
        }
        width = max(width, minNormalizedSize)
        height = max(height, minNormalizedSize)
        let x = min(max(center.x - width / 2, 0), 1 - width)
        let y = min(max(center.y - height / 2, 0), 1 - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func clamp(_ rect: CGRect) -> CGRect {
        var result = rect
        result.size.width = max(result.size.width, minNormalizedSize)
        result.size.height = max(result.size.height, minNormalizedSize)
        if result.size.width > 1 { result.size.width = 1 }
        if result.size.height > 1 { result.size.height = 1 }
        result.origin.x = min(max(result.origin.x, 0), 1 - result.size.width)
        result.origin.y = min(max(result.origin.y, 0), 1 - result.size.height)
        return result
    }

    static func clampLocked(_ rect: CGRect, normalizedAspect: CGFloat) -> CGRect {
        fittedRect(
            normalizedAspect: normalizedAspect,
            center: CGPoint(x: rect.midX, y: rect.midY)
        )
    }
}
