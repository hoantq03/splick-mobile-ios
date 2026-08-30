import Foundation

/// Display zoom (0.5× / 1× / 2×) vs `AVCaptureDevice.videoZoomFactor`.
enum CameraZoom {
    /// Cap shown in UI; hardware may allow more.
    static let uxMaxDisplay: CGFloat = 15

    struct Hardware: Equatable {
        var minVideo: CGFloat
        var maxVideo: CGFloat
        /// `videoZoomFactor` values where the virtual device switches lenses.
        var switchOverVideo: [CGFloat]
        /// `displayZoom = videoZoom * displayMultiplier` (0.5 on Dual/Triple Wide).
        var displayMultiplier: CGFloat

        var minDisplay: CGFloat {
            nice(minVideo * displayMultiplier)
        }

        var maxDisplay: CGFloat {
            min(maxVideo * displayMultiplier, CameraZoom.uxMaxDisplay)
        }

        func display(fromVideo video: CGFloat) -> CGFloat {
            video * displayMultiplier
        }

        func video(fromDisplay display: CGFloat) -> CGFloat {
            guard displayMultiplier > 0 else { return display }
            return display / displayMultiplier
        }

        /// Idle Camera.app pills: ultra-wide, 1×, 2× crop when useful, then tele.
        var presets: [CGFloat] {
            CameraZoom.presets(for: self)
        }
    }

    static func hardware(
        minVideo: CGFloat,
        maxVideo: CGFloat,
        switchOverVideo: [CGFloat],
        systemDisplayMultiplier: CGFloat? = nil
    ) -> Hardware {
        let minV = max(minVideo, 1)
        let maxV = max(minV, maxVideo)
        let overs = switchOverVideo.filter { $0 >= minV - 0.01 && $0 <= maxV + 0.01 }.sorted()
        let multiplier: CGFloat
        if let systemDisplayMultiplier, systemDisplayMultiplier > 0.05, systemDisplayMultiplier <= 1.01 {
            multiplier = systemDisplayMultiplier
        } else if let first = overs.first, first > minV + 0.05 {
            multiplier = 1 / first
        } else {
            multiplier = 1
        }
        return Hardware(
            minVideo: minV,
            maxVideo: maxV,
            switchOverVideo: overs,
            displayMultiplier: multiplier
        )
    }

    static func presets(for hardware: Hardware) -> [CGFloat] {
        let maxD = hardware.maxDisplay
        var values: [CGFloat] = []

        let minD = hardware.minDisplay
        if minD < 0.85, maxD >= minD {
            values.append(minD)
        }
        if maxD >= 0.95 {
            values.append(1)
        }

        let optical = hardware.switchOverVideo
            .map { nice(hardware.display(fromVideo: $0)) }
            .filter { $0 > 1.08 && $0 <= maxD + 0.05 }

        if maxD >= 1.95, !containsFactor(values + optical, 2) {
            values.append(2)
        }
        values.append(contentsOf: optical)

        var seen = Set<Int>()
        return values
            .map { nice($0) }
            .filter { $0 <= maxD + 0.02 }
            .sorted()
            .filter { value in
                let key = Int((value * 10).rounded())
                return seen.insert(key).inserted
            }
    }

    static func clampDisplay(_ factor: CGFloat, hardware: Hardware) -> CGFloat {
        min(max(factor, hardware.minDisplay), hardware.maxDisplay)
    }

    static func applyPinch(base: CGFloat, scale: CGFloat, hardware: Hardware) -> CGFloat {
        let safeScale = scale.isFinite && scale > 0 ? scale : 1
        return clampDisplay(base * safeScale, hardware: hardware)
    }

    /// Horizontal drag on a log scale (native Camera dial).
    static func applyPan(
        base: CGFloat,
        deltaPx: CGFloat,
        viewWidth: CGFloat,
        hardware: Hardware
    ) -> CGFloat {
        let minD = max(hardware.minDisplay, 0.1)
        let maxD = max(hardware.maxDisplay, minD)
        guard deltaPx.isFinite, viewWidth > 1, maxD > minD else {
            return clampDisplay(base, hardware: hardware)
        }
        let logMin = log(minD)
        let logMax = log(maxD)
        let baseLog = log(max(base, minD))
        let t = (baseLog - logMin) / (logMax - logMin)
        let nextT = t + (deltaPx / viewWidth)
        let next = exp(logMin + min(max(nextT, 0), 1) * (logMax - logMin))
        return clampDisplay(next, hardware: hardware)
    }

    static func nextPreset(current: CGFloat, hardware: Hardware) -> CGFloat {
        let available = hardware.presets
        guard !available.isEmpty else { return clampDisplay(current, hardware: hardware) }
        return available.first(where: { $0 > current + 0.08 }) ?? available[0]
    }

    static func nearestPreset(_ current: CGFloat, hardware: Hardware, tolerance: CGFloat = 0.08) -> CGFloat? {
        hardware.presets.first { abs($0 - current) <= tolerance }
    }

    /// 0...1 along the log zoom range for the arc dial.
    static func dialProgress(display: CGFloat, hardware: Hardware) -> CGFloat {
        let minD = max(hardware.minDisplay, 0.1)
        let maxD = max(hardware.maxDisplay, minD)
        guard maxD > minD else { return 0 }
        let t = (log(max(display, minD)) - log(minD)) / (log(maxD) - log(minD))
        return min(max(t, 0), 1)
    }

    static func label(_ factor: CGFloat) -> String {
        let rounded = nice(factor)
        if abs(rounded - rounded.rounded()) < 0.05 {
            return "\(Int(rounded.rounded()))×"
        }
        return String(format: "%.1f×", rounded)
    }

    static func pillLabel(_ factor: CGFloat, isSelected: Bool, currentDisplay: CGFloat) -> String {
        if isSelected {
            return label(currentDisplay)
        }
        return label(factor)
    }

    private static func containsFactor(_ values: [CGFloat], _ target: CGFloat) -> Bool {
        values.contains { abs($0 - target) < 0.08 }
    }

    static func nice(_ value: CGFloat) -> CGFloat {
        (value * 10).rounded() / 10
    }
}

struct CameraFocusIndicator: Equatable {
    let token: UUID
    let point: CGPoint

    init(point: CGPoint) {
        self.token = UUID()
        self.point = point
    }
}

/// Maps a portrait preview tap into `AVCaptureDevice` point-of-interest space.
/// The sensor is landscape: view Y → device X, view X → device Y.
enum CameraFocusMapping {
    static func devicePointOfInterest(
        viewPoint: CGPoint,
        viewSize: CGSize,
        mirrored: Bool
    ) -> CGPoint {
        guard viewSize.width > 1, viewSize.height > 1 else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        let nx = min(max(viewPoint.x / viewSize.width, 0), 1)
        let ny = min(max(viewPoint.y / viewSize.height, 0), 1)
        return CGPoint(
            x: ny,
            y: mirrored ? nx : (1 - nx)
        )
    }
}
