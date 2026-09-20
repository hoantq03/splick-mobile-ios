import CoreGraphics
import SwiftUI

/// Circular “water” reveal from the floating camera control to the capture screen.
public enum CameraOpenRevealGeometry {
    public static func origin(
        in size: CGSize,
        cameraSize: CGFloat,
        bottomInset: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: size.width / 2,
            y: size.height - bottomInset - cameraSize / 2
        )
    }

    public static func coveringRadius(origin: CGPoint, size: CGSize) -> CGFloat {
        let left = origin.x
        let right = size.width - origin.x
        let top = origin.y
        let bottom = size.height - origin.y
        return hypot(max(left, right), max(top, bottom))
    }

    public static func radius(progress: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        lerp(start, end, progress)
    }

    /// Morphs the live preview from the tab camera circle to the resting 8:9 finder.
    /// Metal / UIView preview often ignores SwiftUI masks, so the view itself must grow.
    public static func finderSpread(
        progress: CGFloat,
        cameraSize: CGFloat,
        canvas: CGSize,
        bottomInset: CGFloat,
        restWidth: CGFloat,
        restHeight: CGFloat,
        restCenter: CGPoint,
        restCorner: CGFloat
    ) -> CameraFinderSpread {
        let t = min(max(progress, 0), 1)
        let width = lerp(cameraSize, restWidth, t)
        let height = lerp(cameraSize, restHeight, t)
        let start = origin(in: canvas, cameraSize: cameraSize, bottomInset: bottomInset)
        let center = CGPoint(
            x: lerp(start.x, restCenter.x, t),
            y: lerp(start.y, restCenter.y, t)
        )
        return CameraFinderSpread(
            width: width,
            height: height,
            corner: lerp(cameraSize / 2, restCorner, t),
            left: center.x - width / 2,
            top: center.y - height / 2
        )
    }

    public static func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        let t = min(max(progress, 0), 1)
        return start + (end - start) * t
    }

    /// Extra rise of the shutter row after the water leaves the tab camera.
    public static let shutterRestLift: CGFloat = 56

    public static func shutterRowLift(progress: CGFloat) -> CGFloat {
        min(max(progress, 0), 1) * shutterRestLift
    }

    /// Soft rim; 0 when fully open so the finder stays sharp.
    public static func feather(progress: CGFloat, maxFeather: CGFloat) -> CGFloat {
        let remain = 1 - min(max(progress, 0), 1)
        return remain * remain * maxFeather
    }
}

public struct CameraFinderSpread: Equatable {
    public var width: CGFloat
    public var height: CGFloat
    public var corner: CGFloat
    public var left: CGFloat
    public var top: CGFloat

    public var center: CGPoint {
        CGPoint(x: left + width / 2, y: top + height / 2)
    }
}

public enum CameraOpenRevealMotion {
    /// Overdamped spring — no bounce, long liquid settle.
    public static let expand = Animation.spring(response: 0.58, dampingFraction: 1)
    public static let collapse = Animation.spring(response: 0.46, dampingFraction: 1)
}

public struct CameraOpenRevealMask: ViewModifier {
    public var progress: CGFloat
    public var cameraSize: CGFloat
    public var bottomInset: CGFloat

    public init(progress: CGFloat, cameraSize: CGFloat, bottomInset: CGFloat) {
        self.progress = progress
        self.cameraSize = cameraSize
        self.bottomInset = bottomInset
    }

    public func body(content: Content) -> some View {
        GeometryReader { geo in
            let origin = CameraOpenRevealGeometry.origin(
                in: geo.size,
                cameraSize: cameraSize,
                bottomInset: bottomInset
            )
            let covering = CameraOpenRevealGeometry.coveringRadius(origin: origin, size: geo.size)
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .mask {
                    WaterRevealMaskShape(
                        progress: progress,
                        origin: origin,
                        cameraSize: cameraSize,
                        covering: covering,
                        canvasSize: geo.size
                    )
                }
        }
    }
}

/// Fixed covering circle + GPU scale/blur so the rim interpolates on the render tick.
private struct WaterRevealMaskShape: View, Animatable {
    var progress: CGFloat
    var origin: CGPoint
    var cameraSize: CGFloat
    var covering: CGFloat
    var canvasSize: CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let radius = CameraOpenRevealGeometry.radius(
            progress: progress,
            start: cameraSize / 2,
            end: covering
        )
        let feather = CameraOpenRevealGeometry.feather(
            progress: progress,
            maxFeather: min(canvasSize.width, canvasSize.height) * 0.18
        )
        let scale = max(radius / max(covering, 1), 0.001)
        Circle()
            .fill(Color.white)
            .frame(width: covering * 2, height: covering * 2)
            .scaleEffect(scale, anchor: .center)
            .blur(radius: feather)
            .position(origin)
            .transaction { $0.animation = nil }
    }
}

public extension View {
    func cameraOpenReveal(progress: CGFloat, cameraSize: CGFloat, bottomInset: CGFloat) -> some View {
        modifier(
            CameraOpenRevealMask(
                progress: progress,
                cameraSize: cameraSize,
                bottomInset: bottomInset
            )
        )
    }
}

private struct CameraOpenRevealProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

public extension EnvironmentValues {
    var cameraOpenRevealProgress: CGFloat {
        get { self[CameraOpenRevealProgressKey.self] }
        set { self[CameraOpenRevealProgressKey.self] = newValue }
    }
}
