import Foundation

enum CameraZoom {
    static let uxMax: CGFloat = 10
    static let steps: [CGFloat] = [1, 2, 4, 5, 8, 10]

    static func clamp(_ factor: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        let lo = Swift.max(min, 1)
        let hi = Swift.max(lo, Swift.min(max, uxMax))
        return Swift.min(Swift.max(factor, lo), hi)
    }

    static func applyPinch(base: CGFloat, scale: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        let safeScale = scale.isFinite && scale > 0 ? scale : 1
        return clamp(base * safeScale, min: min, max: max)
    }

    /// Right swipe zooms in; left swipe zooms out. `deltaPx` is translation from gesture start.
    static func applyPan(
        base: CGFloat,
        deltaPx: CGFloat,
        viewWidth: CGFloat,
        min: CGFloat,
        max: CGFloat
    ) -> CGFloat {
        guard deltaPx.isFinite, viewWidth > 1 else { return clamp(base, min: min, max: max) }
        let range = Swift.max(0, clamp(max, min: min, max: max) - clamp(min, min: min, max: max))
        return clamp(base + (deltaPx / viewWidth) * range, min: min, max: max)
    }

    static func nextStep(current: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        let available = steps.map { clamp($0, min: min, max: max) }.uniqued()
        return available.first(where: { $0 > current + 0.08 }) ?? available[0]
    }

    static func label(_ factor: CGFloat) -> String {
        let rounded = (factor * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.05 {
            return "\(Int(rounded))×"
        }
        return String(format: "%.1f×", rounded)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
