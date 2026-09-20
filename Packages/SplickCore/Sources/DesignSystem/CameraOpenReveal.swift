import CoreGraphics
import QuartzCore
import SwiftUI
import UIKit

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

    /// Capture button grows from the tab camera size as the water opens.
    public static let shutterOpenedScale: CGFloat = 1.25

    public static func shutterOpenScale(progress: CGFloat) -> CGFloat {
        lerp(1, shutterOpenedScale, progress)
    }

    /// Soft rim that peaks mid-spread and is 0 at both ends so close does not leave a foggy stain.
    /// Keep narrower than Android's visual soft edge — SwiftUI mask alpha composites with the
    /// underlying tab, so a wide haze reads as feed bleeding into camera chrome.
    public static func feather(progress: CGFloat, maxFeather: CGFloat) -> CGFloat {
        let t = min(max(progress, 0), 1)
        return 4 * t * (1 - t) * maxFeather
    }

    /// Fraction of canvas min-side used as peak feather (matches Android `0.22`).
    public static let maxFeatherFraction: CGFloat = 0.22
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

/// Radial water mask for UIKit camera surfaces that ignore SwiftUI `.mask`.
public enum CameraWaterRevealMask {
    public static func apply(
        to view: UIView,
        originInView: CGPoint,
        radius: CGFloat,
        feather: CGFloat,
        active: Bool
    ) {
        guard active else {
            view.layer.mask = nil
            return
        }
        let outer = max(radius + feather, 0.5)
        let farthest = hypot(
            max(originInView.x, view.bounds.width - originInView.x),
            max(originInView.y, view.bounds.height - originInView.y)
        )
        if radius >= farthest, feather <= 0.5 {
            view.layer.mask = nil
            return
        }
        let gradient: CAGradientLayer
        if let existing = view.layer.mask as? CAGradientLayer {
            gradient = existing
        } else {
            gradient = CAGradientLayer()
            gradient.type = .radial
            view.layer.mask = gradient
        }
        gradient.frame = CGRect(
            x: originInView.x - outer,
            y: originInView.y - outer,
            width: outer * 2,
            height: outer * 2
        )
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        let coreStop = min(max(radius / outer, 0), 1)
        // Keep the soft rim short and mostly opaque so the live preview does not
        // ghost over chrome / the tab underneath.
        let hazeStop = min(coreStop + (1 - coreStop) * 0.22, 0.98)
        gradient.colors = [
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.white.withAlphaComponent(0.88).cgColor,
            UIColor.clear.cgColor,
        ]
        gradient.locations = [0, NSNumber(value: Double(coreStop)), NSNumber(value: Double(hazeStop)), 1]
    }
}

public enum CameraOpenRevealMotion {
    /// Ease-out open that finishes instead of spring-settling (matches Android ExpandSpec).
    public static let expand = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.46)
    public static let collapse = Animation.timingCurve(0.32, 0, 0.18, 1, duration: 0.46)
}

/// Animatable so SwiftUI interpolates `progress` every frame (without this the water jumps).
public struct CameraOpenRevealMask: ViewModifier, Animatable {
    public var progress: CGFloat
    public var cameraSize: CGFloat
    public var bottomInset: CGFloat

    public var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

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
            // Flatten first so BrandAtmosphere translucency cannot composite with the
            // feed under the soft water rim.
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.black)
                .compositingGroup()
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

/// Radial gradient mask — short opaque rim; cheap vs Gaussian blur.
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
            maxFeather: min(canvasSize.width, canvasSize.height)
                * CameraOpenRevealGeometry.maxFeatherFraction
        )
        let outer = max(radius + feather, 0.5)
        let core = min(max(radius / outer, 0), 1)
        let haze = min(core + (1 - core) * 0.22, 0.98)
        Canvas { context, _ in
            let rect = CGRect(
                x: origin.x - outer,
                y: origin.y - outer,
                width: outer * 2,
                height: outer * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: core),
                        .init(color: .white.opacity(0.88), location: haze),
                        .init(color: .clear, location: 1),
                    ]),
                    center: origin,
                    startRadius: 0,
                    endRadius: outer
                )
            )
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
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
