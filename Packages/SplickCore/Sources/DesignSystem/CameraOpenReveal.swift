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

    /// Tab-aligned at progress 0; settles `56 + 18` pt higher once open (matches prior rest).
    public static let shutterRestLift: CGFloat = 74

    /// Lift completes in the first ~70% so the shutter is mostly up before handoff.
    public static func shutterRowLift(progress: CGFloat) -> CGFloat {
        let t = min(max(progress / 0.7, 0), 1)
        return t * shutterRestLift
    }

    public static let shutterOpenedScale: CGFloat = 1.25

    /// Scale grows with the lift (not after) — slide up and enlarge together.
    public static func shutterOpenScale(progress: CGFloat) -> CGFloat {
        let t = min(max(progress / 0.7, 0), 1)
        return lerp(1, shutterOpenedScale, t)
    }

    public static func feather(progress: CGFloat, maxFeather: CGFloat) -> CGFloat {
        let t = min(max(progress, 0), 1)
        return 4 * t * (1 - t) * maxFeather
    }

    public static let maxFeatherFraction: CGFloat = 0.12

    /// Near-linear so the disk visibly grows from the shutter (not a fog pop).
    public static func expandEase(_ t: CGFloat) -> CGFloat {
        unitBezier(t, c1x: 0.4, c1y: 0.0, c2x: 0.2, c2y: 1)
    }

    /// Matches Android CollapseSpec with a slightly gentler finish.
    public static func collapseEase(_ t: CGFloat) -> CGFloat {
        unitBezier(t, c1x: 0.32, c1y: 0, c2x: 0.2, c2y: 1)
    }

    private static func unitBezier(
        _ t: CGFloat,
        c1x: CGFloat,
        c1y: CGFloat,
        c2x: CGFloat,
        c2y: CGFloat
    ) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        // Newton solve for x(t) = clamped, then sample y.
        var guess = clamped
        for _ in 0..<6 {
            let x = sampleCurve(guess, a: c1x, b: c2x)
            let dx = sampleCurveDerivative(guess, a: c1x, b: c2x)
            if abs(dx) < 1e-6 { break }
            guess -= (x - clamped) / dx
            guess = min(max(guess, 0), 1)
        }
        return sampleCurve(guess, a: c1y, b: c2y)
    }

    private static func sampleCurve(_ t: CGFloat, a: CGFloat, b: CGFloat) -> CGFloat {
        // (1-t)^3*0 + 3(1-t)^2*t*a + 3(1-t)*t^2*b + t^3*1
        let oneMinus = 1 - t
        return 3 * oneMinus * oneMinus * t * a
            + 3 * oneMinus * t * t * b
            + t * t * t
    }

    private static func sampleCurveDerivative(_ t: CGFloat, a: CGFloat, b: CGFloat) -> CGFloat {
        let oneMinus = 1 - t
        return 3 * oneMinus * oneMinus * a
            + 6 * oneMinus * t * (b - a)
            + 3 * t * t * (1 - b)
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
    /// ~15% faster than the prior 0.72s open/close water motion.
    public static let duration: TimeInterval = 0.612
    /// Kept for call sites that still use SwiftUI animations (tab chrome fades).
    public static let expand = Animation.timingCurve(0.33, 0.0, 0.2, 1, duration: duration)
    public static let collapse = Animation.timingCurve(0.32, 0, 0.2, 1, duration: duration)
}

/// Progress bridge updated by the UIKit water mask display-link.
///
/// Own this with `@State` (not `@StateObject`) in the tab root so per-frame
/// publishes do not rebuild `CameraOpenRevealContainer` mid-animation.
public final class CameraOpenRevealProgressSource: ObservableObject {
    @Published public var value: CGFloat = 0

    public init(value: CGFloat = 0) {
        self.value = value
    }

    public func setValue(_ next: CGFloat) {
        let clamped = min(max(next, 0), 1)
        if abs(value - clamped) > 0.001 {
            value = clamped
        }
    }
}

/// Radial water mask for UIKit surfaces that ignore SwiftUI `.mask` (Metal / AR).
/// Prefer the parent `CameraOpenRevealContainer` mask during open/close — calling this
/// every SwiftUI frame is expensive.
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
        let outer = max(radius + max(feather, 2), 0.5)
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
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        let coreStop = min(max(radius / outer, 0), 0.98)
        let hazeStop = min(max(coreStop + (1 - coreStop) * 0.2, coreStop), 0.99)
        gradient.colors = [
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.white.withAlphaComponent(0.85).cgColor,
            UIColor.clear.cgColor,
        ]
        gradient.locations = [
            0,
            NSNumber(value: Double(coreStop)),
            NSNumber(value: Double(hazeStop)),
            1,
        ]
    }
}

// MARK: - UIKit host (GPU mask — does not invalidate SwiftUI every frame)

/// Hosts camera content and expands/collapses a solid circular mask on the display link.
public struct CameraOpenRevealContainer<Content: View>: UIViewControllerRepresentable {
    public var isExpanded: Bool
    public var cameraSize: CGFloat
    public var bottomInset: CGFloat
    public var progressSource: CameraOpenRevealProgressSource?
    public var onCollapseFinished: (() -> Void)?
    public var content: Content

    public init(
        isExpanded: Bool,
        cameraSize: CGFloat,
        bottomInset: CGFloat,
        progressSource: CameraOpenRevealProgressSource? = nil,
        onCollapseFinished: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isExpanded = isExpanded
        self.cameraSize = cameraSize
        self.bottomInset = bottomInset
        self.progressSource = progressSource
        self.onCollapseFinished = onCollapseFinished
        self.content = content()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIViewController(context: Context) -> CameraOpenRevealHostController<Content> {
        let controller = CameraOpenRevealHostController(
            rootView: content,
            cameraSize: cameraSize,
            bottomInset: bottomInset
        )
        controller.onCollapseFinished = onCollapseFinished
        controller.progressSource = progressSource
        // Mount at the tab camera circle; expand on first update when `isExpanded` is true.
        context.coordinator.lastExpanded = false
        controller.applyProgress(0, animated: false)
        return controller
    }

    public func updateUIViewController(
        _ controller: CameraOpenRevealHostController<Content>,
        context: Context
    ) {
        controller.cameraSize = cameraSize
        controller.bottomInset = bottomInset
        controller.onCollapseFinished = onCollapseFinished
        controller.progressSource = progressSource
        // Skip root updates while the water is moving — resetting UIHostingController
        // content every SwiftUI pass is a major open/close hitch.
        if !controller.isAnimatingWater {
            controller.updateRootView(content)
        }
        if context.coordinator.lastExpanded != isExpanded {
            context.coordinator.lastExpanded = isExpanded
            controller.applyProgress(isExpanded ? 1 : 0, animated: true)
        }
    }

    public final class Coordinator {
        var lastExpanded: Bool?
    }
}

public final class CameraOpenRevealHostController<Content: View>: UIViewController {
    var cameraSize: CGFloat
    var bottomInset: CGFloat
    var onCollapseFinished: (() -> Void)?
    weak var progressSource: CameraOpenRevealProgressSource?
    private(set) var isAnimatingWater = false

    private let hosting: UIHostingController<Content>
    /// Solid growing circle from the tab shutter — radius expands (the “loang”).
    private let maskLayer = CAShapeLayer()
    private var progress: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var animationFrom: CGFloat = 0
    private var animationTo: CGFloat = 0
    private var animationStart: CFTimeInterval = 0
    private var animationExpanding = true
    private var pendingRootView: Content?
    private var pendingAnimatedTarget: CGFloat?

    init(rootView: Content, cameraSize: CGFloat, bottomInset: CGFloat) {
        self.cameraSize = cameraSize
        self.bottomInset = bottomInset
        self.hosting = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override public func loadView() {
        let root = UIView()
        root.backgroundColor = .clear
        root.isOpaque = false
        view = root
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.clipsToBounds = true

        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 16.4, *) {
            hosting.safeAreaRegions = []
        }
        addChild(hosting)
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosting.didMove(toParent: self)

        maskLayer.fillColor = UIColor.white.cgColor
        maskLayer.backgroundColor = UIColor.clear.cgColor
        view.layer.mask = maskLayer
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyMask(for: progress)
        if let pending = pendingAnimatedTarget,
           view.bounds.width > 1,
           view.bounds.height > 1 {
            pendingAnimatedTarget = nil
            applyProgress(pending, animated: true)
        }
    }

    func updateRootView(_ rootView: Content) {
        if isAnimatingWater {
            pendingRootView = rootView
            return
        }
        hosting.rootView = rootView
    }

    func applyProgress(_ target: CGFloat, animated: Bool) {
        let clamped = min(max(target, 0), 1)
        stopDisplayLink()
        let hasSize = view.bounds.width > 1 && view.bounds.height > 1
        if animated, !hasSize {
            pendingAnimatedTarget = clamped
            applyMask(for: progress)
            publishProgress(progress)
            return
        }
        guard animated, abs(clamped - progress) > 0.001 else {
            pendingAnimatedTarget = nil
            progress = clamped
            applyMask(for: progress)
            publishProgress(progress)
            flushPendingRootView()
            return
        }
        pendingAnimatedTarget = nil
        isAnimatingWater = true
        animationFrom = progress
        animationTo = clamped
        animationExpanding = clamped > progress
        animationStart = CACurrentMediaTime()
        if animationExpanding {
            applyMask(for: progress)
        } else {
            // Collapse from a settled open state (mask was removed). Re-attach at
            // nearly-full coverage so the first frame is not an unmasked flash.
            if view.layer.mask !== maskLayer {
                view.layer.mask = maskLayer
            }
            applyMask(for: min(max(progress, 0), 0.998))
        }
        publishProgress(progress)
        let link = CADisplayLink(target: self, selector: #selector(tickAnimation))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tickAnimation() {
        let elapsed = CACurrentMediaTime() - animationStart
        let linear = min(max(elapsed / CameraOpenRevealMotion.duration, 0), 1)
        let eased = animationExpanding
            ? CameraOpenRevealGeometry.expandEase(linear)
            : CameraOpenRevealGeometry.collapseEase(linear)
        progress = CameraOpenRevealGeometry.lerp(animationFrom, animationTo, eased)
        applyMask(for: progress)
        publishProgress(progress)
        if linear >= 1 {
            progress = animationTo
            applyMask(for: progress)
            publishProgress(progress)
            stopDisplayLink()
            isAnimatingWater = false
            flushPendingRootView()
            if progress <= 0.001 {
                onCollapseFinished?()
            }
        }
    }

    private func publishProgress(_ value: CGFloat) {
        progressSource?.setValue(value)
    }

    private func flushPendingRootView() {
        if let pendingRootView {
            hosting.rootView = pendingRootView
            self.pendingRootView = nil
        }
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func applyMask(for progress: CGFloat) {
        let size = view.bounds.size
        guard size.width > 1, size.height > 1 else { return }
        let origin = CameraOpenRevealGeometry.origin(
            in: size,
            cameraSize: cameraSize,
            bottomInset: bottomInset
        )
        let covering = CameraOpenRevealGeometry.coveringRadius(origin: origin, size: size)
        // Opaque disk grows from the shutter — this is the visible “loang”.
        let radius = CameraOpenRevealGeometry.radius(
            progress: progress,
            start: max(cameraSize / 2, 1),
            end: covering
        )
        // Soft rim outside the core (peaks mid-spread). Drawn as a translucent stroke so
        // the bloom stays a crisp growing disk, not a full-screen fog fade.
        let maxFeather = min(size.width, size.height) * CameraOpenRevealGeometry.maxFeatherFraction
        let feather = CameraOpenRevealGeometry.feather(progress: progress, maxFeather: maxFeather)

        if progress >= 0.999 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            view.layer.mask = nil
            CATransaction.commit()
            return
        }

        if view.layer.mask !== maskLayer {
            view.layer.mask = maskLayer
        }

        let coreRect = CGRect(
            x: origin.x - radius,
            y: origin.y - radius,
            width: max(radius * 2, 1),
            height: max(radius * 2, 1)
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = view.bounds
        maskLayer.path = UIBezierPath(ovalIn: coreRect).cgPath
        maskLayer.fillColor = UIColor.white.cgColor
        if feather > 1.5 {
            // Stroke centered on the path edge: outer half softens the rim in the mask alpha.
            maskLayer.lineWidth = feather * 2
            maskLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        } else {
            maskLayer.lineWidth = 0
            maskLayer.strokeColor = nil
        }
        CATransaction.commit()
    }

    deinit {
        stopDisplayLink()
    }
}

// MARK: - Environment (settled 0/1 only — do not animate through SwiftUI)

private struct CameraOpenRevealProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

public extension EnvironmentValues {
    /// Settled reveal progress for chrome layout (0 or 1). Do not drive this every frame.
    var cameraOpenRevealProgress: CGFloat {
        get { self[CameraOpenRevealProgressKey.self] }
        set { self[CameraOpenRevealProgressKey.self] = newValue }
    }
}
