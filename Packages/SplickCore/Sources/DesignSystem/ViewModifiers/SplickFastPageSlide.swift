import SwiftUI
import UIKit

/// Horizontal page slide used by tab pagers and `NavigationStack` push/pop.
/// Default UIKit navigation is ~0.35s — this matches Android's 220ms tab slide, slightly faster.
public enum SplickPageSlideMotion {
    public static let duration: TimeInterval = 0.16
    public static let animation = Animation.easeOut(duration: duration)
}

/// Marks a programmatic push that should keep iOS 18 `navigationTransition(.zoom)`.
/// The custom slide animator must not steal that push — otherwise detail only morphs on pop.
/// Main-thread only (UIKit navigation callbacks).
public enum SplickZoomNavigation {
    public static var isPushPending = false

    public static func preparePush() {
        isPushPending = true
    }

    public static func clearPending() {
        isPushPending = false
    }
}

extension View {
    /// Speeds `NavigationStack` push/pop (non-zoom) to [SplickPageSlideMotion.duration].
    /// System zoom transitions (iOS 18 feed → post) and interactive swipe-back stay native.
    public func splickFastPageSlide() -> some View {
        background(SplickFastPageSlideInstaller())
    }

    /// Keeps UIKit edge swipe-back enabled inside custom-gesture screens (e.g. chat thread)
    /// without replacing `UINavigationController.delegate` (that steals iOS 18 zoom).
    public func splickInteractivePopEnabled() -> some View {
        background(SplickInteractivePopEnabler())
    }

    /// Physical-bezel swipe-back only. Disables the stock (wide) interactive-pop recognizer
    /// and any widened pop band, then installs a screen-edge pan for chat reply screens.
    public func splickEdgeOnlyInteractivePop(edgeWidth: CGFloat = SplickEdgeInteractivePop.edgeWidth) -> some View {
        background(SplickEdgeOnlyInteractivePopInstaller(edgeWidth: edgeWidth))
    }

    /// Widens interactive pop to the leading quarter of the screen (same as Android post detail).
    /// On iOS 18 zoom destinations (feed → post) the extra pan is disabled — zoom dismiss is
    /// bound to the system edge gesture, and a second pan only pops after the finger lifts.
    public func splickWideInteractivePop(fraction: CGFloat = 0.25, minimumWidth: CGFloat = 0) -> some View {
        background(SplickWideInteractivePopInstaller(fraction: fraction, minimumWidth: minimumWidth))
    }

    /// Post detail: swipe-back from anywhere, but only when the drag is clearly horizontal so
    /// pull-to-refresh does not accidentally pop. iOS 18+ zoom already tracks off-edge; older
    /// iOS drives the same `handleNavigationTransition:` from a full-screen pan.
    public func splickHorizontalDominantInteractivePop(
        fraction: CGFloat = 1,
        minimumWidth: CGFloat = 0
    ) -> some View {
        background(
            SplickHorizontalDominantInteractivePopInstaller(
                fraction: fraction,
                minimumWidth: minimumWidth
            )
        )
    }
}

private struct SplickInteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SplickInteractivePopHostController {
        SplickInteractivePopHostController()
    }

    func updateUIViewController(_ uiViewController: SplickInteractivePopHostController, context: Context) {
        uiViewController.enableIfNeeded()
    }
}

/// Replaces the stock interactive-pop recognizer with a thin leading-edge pan.
/// Stock UIKit edge pop is too wide for chat — it steals swipe-to-reply on short incoming bubbles.
private struct SplickEdgeOnlyInteractivePopInstaller: UIViewControllerRepresentable {
    var edgeWidth: CGFloat

    func makeUIViewController(context: Context) -> SplickEdgeOnlyInteractivePopHostController {
        let host = SplickEdgeOnlyInteractivePopHostController()
        host.edgeWidth = edgeWidth
        return host
    }

    func updateUIViewController(_ uiViewController: SplickEdgeOnlyInteractivePopHostController, context: Context) {
        uiViewController.edgeWidth = edgeWidth
        uiViewController.enableIfNeeded()
    }

    static func dismantleUIViewController(_ uiViewController: SplickEdgeOnlyInteractivePopHostController, coordinator: ()) {
        uiViewController.restoreSystemPopIfNeeded()
    }
}

private final class SplickEdgeOnlyInteractivePopHostController: UIViewController {
    var edgeWidth: CGFloat = SplickEdgeInteractivePop.edgeWidth

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableIfNeeded()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            restoreSystemPopIfNeeded()
        } else {
            enableIfNeeded()
        }
    }

    func enableIfNeeded() {
        guard let nav = resolvedNavigationController() else {
            // Nav is often not in the responder chain on the first SwiftUI pass.
            for delay in [0.0, 0.05, 0.2] as [TimeInterval] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, let nav = self.resolvedNavigationController() else { return }
                    SplickStrictEdgePopGesture.install(on: nav, edgeWidth: self.edgeWidth)
                }
            }
            return
        }
        SplickStrictEdgePopGesture.install(on: nav, edgeWidth: edgeWidth)
    }

    func restoreSystemPopIfNeeded() {
        guard let nav = resolvedNavigationController() else { return }
        SplickStrictEdgePopGesture.uninstall(on: nav)
    }

    private func resolvedNavigationController() -> UINavigationController? {
        navigationController ?? SplickNavigationLookup.navigationController(from: view)
    }
}

/// Enables the system edge-swipe pop without installing a custom push/pop animator.
private final class SplickInteractivePopHostController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableIfNeeded()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        enableIfNeeded()
    }

    func enableIfNeeded() {
        guard let nav = navigationController ?? ancestorNavigationController() else { return }
        SplickInteractivePopConfigurator.apply(to: nav)
    }

    private func ancestorNavigationController() -> UINavigationController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let nav = current as? UINavigationController {
                return nav
            }
            responder = current.next
        }
        return nil
    }
}

/// Installs a leading-quarter pan on `UINavigationController.view` without stealing edge hits.
/// The overlay approach blocked `interactivePopGestureRecognizer`, so zoom only popped on lift.
private struct SplickWideInteractivePopInstaller: UIViewControllerRepresentable {
    var fraction: CGFloat
    var minimumWidth: CGFloat

    func makeUIViewController(context: Context) -> SplickWideInteractivePopHostController {
        let host = SplickWideInteractivePopHostController()
        host.fraction = fraction
        host.minimumWidth = minimumWidth
        return host
    }

    func updateUIViewController(_ uiViewController: SplickWideInteractivePopHostController, context: Context) {
        uiViewController.fraction = fraction
        uiViewController.minimumWidth = minimumWidth
        uiViewController.installIfNeeded()
    }
}

/// Post detail only: requires a clearly horizontal drag before interactive pop begins.
private struct SplickHorizontalDominantInteractivePopInstaller: UIViewControllerRepresentable {
    var fraction: CGFloat
    var minimumWidth: CGFloat

    func makeUIViewController(context: Context) -> SplickHorizontalDominantInteractivePopHostController {
        let host = SplickHorizontalDominantInteractivePopHostController()
        host.fraction = fraction
        host.minimumWidth = minimumWidth
        return host
    }

    func updateUIViewController(
        _ uiViewController: SplickHorizontalDominantInteractivePopHostController,
        context: Context
    ) {
        uiViewController.fraction = fraction
        uiViewController.minimumWidth = minimumWidth
        uiViewController.installIfNeeded()
    }

    static func dismantleUIViewController(
        _ uiViewController: SplickHorizontalDominantInteractivePopHostController,
        coordinator: ()
    ) {
        uiViewController.deactivateIfNeeded()
    }
}

private final class SplickHorizontalDominantInteractivePopHostController: UIViewController {
    var fraction: CGFloat = 1
    var minimumWidth: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installIfNeeded()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            deactivateIfNeeded()
        } else {
            installIfNeeded()
        }
    }

    func installIfNeeded() {
        guard let nav = resolvedNavigationController() else {
            // Nav might not be in the responder chain yet. Retry.
            for delay in [0.0, 0.05, 0.2] as [TimeInterval] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, let nav = self.resolvedNavigationController() else { return }
                    self.doInstall(on: nav)
                }
            }
            return
        }
        doInstall(on: nav)
    }

    private func doInstall(on nav: UINavigationController) {
        SplickHorizontalDominantPopMode.activate(on: nav, fraction: fraction, minimumWidth: minimumWidth)
        SplickWidePopGesture.install(on: nav, fraction: fraction, minimumWidth: minimumWidth)
        // Zoom guard is installed inside `attach` only when the destination actually zooms.
        // Re-installing it here replaced `pop.delegate` on iOS 17 and broke target binding.
    }

    func deactivateIfNeeded() {
        guard let nav = resolvedNavigationController() else { return }
        SplickHorizontalDominantPopMode.deactivate(on: nav)
    }

    private func resolvedNavigationController() -> UINavigationController? {
        navigationController ?? SplickNavigationLookup.navigationController(from: view)
    }
}

private final class SplickHorizontalDominantPopMode {
    private static var associatedKey: UInt8 = 0

    var fraction: CGFloat = 0.25
    var minimumWidth: CGFloat = 0

    static func activate(on nav: UINavigationController, fraction: CGFloat, minimumWidth: CGFloat) {
        let mode = SplickHorizontalDominantPopMode()
        mode.fraction = fraction
        mode.minimumWidth = minimumWidth
        objc_setAssociatedObject(nav, &associatedKey, mode, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func deactivate(on nav: UINavigationController) {
        objc_setAssociatedObject(nav, &associatedKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        SplickZoomPopHorizontalGuard.uninstall(on: nav)
        SplickWidePopGesture.refresh(on: nav)
        SplickInteractivePopConfigurator.apply(to: nav)
    }

    static func isActive(on nav: UINavigationController) -> Bool {
        objc_getAssociatedObject(nav, &associatedKey) is SplickHorizontalDominantPopMode
    }
}

/// Filters iOS 18 zoom interactive pop so vertical pulls (e.g. refresh) do not dismiss.
private final class SplickZoomPopHorizontalGuard: NSObject, UIGestureRecognizerDelegate {
    private static var associatedKey: UInt8 = 0

    private weak var navigationController: UINavigationController?

    static func refresh(on nav: UINavigationController) {
        guard SplickHorizontalDominantPopMode.isActive(on: nav) else {
            uninstall(on: nav)
            return
        }
        install(on: nav)
    }

    static func install(on nav: UINavigationController) {
        guard let pop = nav.interactivePopGestureRecognizer else { return }
        let guardObj: SplickZoomPopHorizontalGuard
        if let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickZoomPopHorizontalGuard {
            guardObj = existing
        } else {
            guardObj = SplickZoomPopHorizontalGuard()
            objc_setAssociatedObject(nav, &associatedKey, guardObj, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        guardObj.navigationController = nav
        pop.delegate = guardObj
    }

    static func uninstall(on nav: UINavigationController) {
        guard let guardObj = objc_getAssociatedObject(nav, &associatedKey) as? SplickZoomPopHorizontalGuard else {
            return
        }
        if nav.interactivePopGestureRecognizer?.delegate === guardObj {
            nav.interactivePopGestureRecognizer?.delegate = nil
        }
        objc_setAssociatedObject(nav, &associatedKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = navigationController,
              gestureRecognizer === nav.interactivePopGestureRecognizer,
              nav.viewControllers.count > 1,
              let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let view = nav.view else {
            return false
        }
        let translation = pan.translation(in: view)
        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        return SplickInteractivePopAxis.isOutwardHorizontalPop(
            translation: translation,
            isRightToLeft: rtl
        )
    }
}

private final class SplickWideInteractivePopHostController: UIViewController {
    var fraction: CGFloat = 0.25
    var minimumWidth: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installIfNeeded()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        installIfNeeded()
    }

    func installIfNeeded() {
        guard let nav = navigationController ?? ancestorNavigationController() else { return }
        SplickWidePopGesture.install(on: nav, fraction: fraction, minimumWidth: minimumWidth)
    }

    private func ancestorNavigationController() -> UINavigationController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let nav = current as? UINavigationController {
                return nav
            }
            responder = current.next
        }
        return nil
    }
}

/// Shared axis checks for interactive pop gestures (wide band, zoom edge pop, post detail).
public enum SplickInteractivePopAxis {
    /// dx must exceed dy × ratio for the swipe to count as "horizontal".
    /// 3.0 ≈ ±18° from the X-axis — tight enough that pull-to-refresh (≈90°)
    /// and diagonal drags (≈45°) never accidentally pop.
    public static let horizontalDominanceRatio: CGFloat = 3.0
    /// Minimum horizontal travel (pt) before the pop can begin.
    public static let minimumHorizontalTranslation: CGFloat = 16

    public static func isHorizontalDominant(
        translation: CGPoint,
        ratio: CGFloat = horizontalDominanceRatio,
        minimumHorizontal: CGFloat = minimumHorizontalTranslation
    ) -> Bool {
        let dx = abs(translation.x)
        let dy = abs(translation.y)
        return dx >= minimumHorizontal && dx > dy * ratio
    }

    public static func isOutwardHorizontalPop(
        translation: CGPoint,
        velocity: CGPoint = .zero,
        isRightToLeft: Bool,
        ratio: CGFloat = horizontalDominanceRatio,
        minimumHorizontal: CGFloat = minimumHorizontalTranslation
    ) -> Bool {
        let outwardTranslation = isRightToLeft ? -translation.x : translation.x
        let outwardVelocity = isRightToLeft ? -velocity.x : velocity.x
        if outwardTranslation >= minimumHorizontal,
           isHorizontalDominant(translation: translation, ratio: ratio, minimumHorizontal: minimumHorizontal) {
            return true
        }
        // Decide early from velocity so content scroll can fail-or-begin quickly.
        return outwardVelocity > 180
            && abs(velocity.x) > abs(velocity.y) * ratio
    }
}

/// Leading-bezel width for chat back-swipe. Stock `NavigationStack` pop is much wider
/// and steals swipe-to-reply on short incoming bubbles / avatars.
///
/// Base band is intentionally wider than list padding (~system edge feel) so bezel
/// pop is hittable on device. Messaging installs `contentOwnsTouch` so avatar/bubble
/// touches inside that band still prefer swipe-to-reply.
///
/// Landscape notch adds `safeAreaInsets.leading` via `resolvedEdgeWidth(for:)`.
public enum SplickEdgeInteractivePop {
    /// Portrait bezel width (before leading safe-area). Wider than list padding so
    /// fingers can start a pop; reply wins via `contentOwnsTouch` on avatar/bubble.
    public static let edgeWidth: CGFloat = 20

    /// Window-space probe: when true, edge pop must yield (avatar / bubble reply).
    /// Installed by the chat list; cleared on detach. Main-thread only.
    public static var contentOwnsTouch: ((CGPoint) -> Bool)?

    /// Bezel width including leading safe area (notch / Dynamic Island landscape).
    public static func resolvedEdgeWidth(
        for view: UIView,
        base: CGFloat = edgeWidth
    ) -> CGFloat {
        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let leadingInset = rtl ? view.safeAreaInsets.right : view.safeAreaInsets.left
        return max(0, leadingInset) + base
    }

    /// Exclusive leading band: LTR `x < edgeWidth`, RTL `x > viewWidth - edgeWidth`.
    public static func isInLeadingEdgeBand(
        x: CGFloat,
        viewWidth: CGFloat,
        isRightToLeft: Bool,
        edgeWidth: CGFloat = edgeWidth
    ) -> Bool {
        if isRightToLeft {
            return x > viewWidth - edgeWidth
        }
        return x < edgeWidth
    }

    /// Ensure edge-pop is installed and the scroll view's built-in pan waits for it.
    /// Safe to call repeatedly. Does **not** make edge wait for any chat list pan.
    /// Skips rebinding while an edge pan is in flight (SwiftUI update storms cancelled pops).
    public static func refreshAndPrefer(overScrollPan scrollPan: UIGestureRecognizer, from view: UIView) {
        guard let nav = SplickNavigationLookup.navigationController(from: view) else { return }
        SplickStrictEdgePopGesture.install(on: nav, edgeWidth: edgeWidth)
        if let edge = SplickStrictEdgePopGesture.edgePan(on: nav) {
            scrollPan.require(toFail: edge)
        }
    }
}

/// Thin leading-band pop used by chat. Disables stock interactive-pop (too wide) and
/// drives the same `handleNavigationTransition:` from a **banded `UIPanGestureRecognizer`**
/// so the page tracks 1:1 under the finger.
///
/// Failure graph (must stay acyclic):
/// - Built-in `UIScrollView` pan waits for this edge pan (`require(toFail:)` + delegate).
/// - Chat list pan does **not** wait for edge; exclusive `shouldReceive` bands instead.
/// - Never `edge.require(toFail: list)`.
private final class SplickStrictEdgePopGesture: NSObject, UIGestureRecognizerDelegate {
    private static var associatedKey: UInt8 = 0

    private weak var navigationController: UINavigationController?
    private var pan: UIPanGestureRecognizer?
    var edgeWidth: CGFloat = SplickEdgeInteractivePop.edgeWidth
    private var touchStartX: CGFloat = .greatestFiniteMagnitude
    private var pausedScrollViews: [UIScrollView] = []
    /// Top VC at gesture begin — used to avoid double-pop if system transition already handled it.
    private weak var popSourceViewController: UIViewController?
    /// True when system interactive targets were bound (percent-driven slide).
    private var hasSystemTransitionTarget = false

    static func install(on nav: UINavigationController, edgeWidth: CGFloat) {
        let owner: SplickStrictEdgePopGesture
        if let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickStrictEdgePopGesture {
            owner = existing
        } else {
            owner = SplickStrictEdgePopGesture()
            objc_setAssociatedObject(nav, &associatedKey, owner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        owner.edgeWidth = edgeWidth
        owner.attach(to: nav)
    }

    static func uninstall(on nav: UINavigationController) {
        guard let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickStrictEdgePopGesture else {
            return
        }
        existing.detach(restoringSystemPop: true)
        objc_setAssociatedObject(nav, &associatedKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func refresh(on nav: UINavigationController) {
        guard let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickStrictEdgePopGesture else {
            return
        }
        existing.attach(to: nav)
    }

    static func isInstalled(on nav: UINavigationController) -> Bool {
        objc_getAssociatedObject(nav, &associatedKey) is SplickStrictEdgePopGesture
    }

    static func edgePan(on nav: UINavigationController) -> UIGestureRecognizer? {
        (objc_getAssociatedObject(nav, &associatedKey) as? SplickStrictEdgePopGesture)?.pan
    }

    private func attach(to nav: UINavigationController) {
        navigationController = nav
        guard let systemPop = nav.interactivePopGestureRecognizer else { return }

        SplickWidePopGesture.forceDisable(on: nav)
        systemPop.isEnabled = false

        // Migrate off delayed recognizer (early `.began` broke 1:1 system tracking).
        if let existing = pan, existing is SplickDelayedEdgePopPanGestureRecognizer {
            existing.view?.removeGestureRecognizer(existing)
            pan = nil
        }

        let inFlight: Bool = {
            guard let pan else { return false }
            switch pan.state {
            case .began, .changed:
                return true
            default:
                return false
            }
        }()

        // Never rebuild / rebind while the finger is driving an interactive pop —
        // SwiftUI updateUIView storms were cancelling mid-swipe on iOS 17.
        if inFlight {
            pan?.isEnabled = nav.viewControllers.count > 1
            return
        }

        if pan == nil {
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
            gesture.name = "splick.chat.edgePop"
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            nav.view.addGestureRecognizer(gesture)
            pan = gesture
        } else if pan?.view !== nav.view, let pan {
            pan.view?.removeGestureRecognizer(pan)
            nav.view.addGestureRecognizer(pan)
        }

        bindTargets(from: systemPop, onto: pan)
        pan?.isEnabled = nav.viewControllers.count > 1
        suppressInteriorNavigationPops(on: nav, keeping: pan)

        DispatchQueue.main.async { [weak self, weak nav] in
            guard let self, let nav else { return }
            let flying: Bool = {
                guard let pan = self.pan else { return false }
                switch pan.state {
                case .began, .changed: return true
                default: return false
                }
            }()
            guard !flying else { return }
            self.bindTargets(from: systemPop, onto: self.pan)
            self.pan?.isEnabled = nav.viewControllers.count > 1
            self.suppressInteriorNavigationPops(on: nav, keeping: self.pan)
        }
    }

    private func detach(restoringSystemPop: Bool) {
        restorePausedScrollViews()
        if let pan, let view = pan.view {
            view.removeGestureRecognizer(pan)
        }
        pan = nil
        if restoringSystemPop, let nav = navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = nav.viewControllers.count > 1
        }
        navigationController = nil
    }

    private func bindTargets(from systemPop: UIGestureRecognizer, onto pan: UIPanGestureRecognizer?) {
        guard let pan else { return }
        hasSystemTransitionTarget = false

        // Drive the same percent-driven transition as stock edge-pop (1:1 under finger).
        if let targets = systemPop.value(forKey: "targets") {
            pan.setValue(targets, forKey: "targets")
            hasSystemTransitionTarget = true
        }

        let selector = NSSelectorFromString("handleNavigationTransition:")
        if let transition = systemPop.delegate, transition.responds(to: selector) {
            let current = pan.value(forKey: "targets")
            let isEmpty: Bool = {
                if current == nil { return true }
                if let array = current as? NSArray { return array.count == 0 }
                return false
            }()
            if isEmpty {
                pan.addTarget(transition, action: selector)
                hasSystemTransitionTarget = true
            }
        }

        // Scroll pause + rare fallback when SwiftUI ignores system targets.
        pan.removeTarget(self, action: #selector(handleEdgePan(_:)))
        pan.addTarget(self, action: #selector(handleEdgePan(_:)))
    }

    @objc private func handleEdgePan(_ gesture: UIPanGestureRecognizer) {
        guard let nav = navigationController, let view = nav.view else { return }

        switch gesture.state {
        case .began:
            // Refuse if the touch did not start on the physical bezel.
            guard touchStartX != .greatestFiniteMagnitude,
                  isInStrictEdgeBand(point: CGPoint(x: touchStartX, y: view.bounds.midY), in: view)
            else {
                gesture.isEnabled = false
                gesture.isEnabled = true
                return
            }
            // Dismiss keyboard before the interactive transition tracks — animated
            // keyboard constraint fights cancel the pop on iOS 17 (Autolayout spam).
            UIView.performWithoutAnimation {
                nav.view.window?.endEditing(true)
            }
            popSourceViewController = nav.topViewController
            pauseScrollViews(under: nav)
        case .changed:
            break
        case .ended, .cancelled, .failed:
            defer {
                restorePausedScrollViews()
                popSourceViewController = nil
            }
            guard gesture.state == .ended else { return }
            guard touchStartX != .greatestFiniteMagnitude,
                  isInStrictEdgeBand(point: CGPoint(x: touchStartX, y: view.bounds.midY), in: view)
            else { return }
            // System interactive pop already finished or cancelled itself.
            if nav.topViewController !== popSourceViewController { return }
            if nav.transitionCoordinator != nil { return }
            // System targets own complete/cancel for 1:1 tracking — do not second-guess
            // with a deferred pop (that felt like “only moves after lift”).
            guard !hasSystemTransitionTarget else { return }
            attemptFallbackPop(nav: nav, gesture: gesture, in: view)
        default:
            break
        }
    }

    private func attemptFallbackPop(
        nav: UINavigationController,
        gesture: UIPanGestureRecognizer,
        in view: UIView
    ) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let outwardDistance = rtl ? -translation.x : translation.x
        let outwardVelocity = rtl ? -velocity.x : velocity.x
        // Stricter than before — must clearly intend to leave, and only from bezel start.
        let shouldPop = outwardDistance > view.bounds.width * 0.35
            || (outwardDistance > 80 && outwardVelocity > 500)
        guard shouldPop, nav.viewControllers.count > 1 else { return }
        nav.popViewController(animated: true)
    }

    private func pauseScrollViews(under nav: UINavigationController) {
        restorePausedScrollViews()
        var found: [UIScrollView] = []
        func walk(_ view: UIView) {
            if let scroll = view as? UIScrollView, scroll.isScrollEnabled {
                found.append(scroll)
            }
            view.subviews.forEach(walk)
        }
        if let root = nav.visibleViewController?.view {
            walk(root)
        }
        for scroll in found {
            scroll.isScrollEnabled = false
        }
        pausedScrollViews = found
    }

    private func restorePausedScrollViews() {
        for scroll in pausedScrollViews {
            scroll.isScrollEnabled = true
        }
        pausedScrollViews = []
    }

    private func suppressInteriorNavigationPops(on nav: UINavigationController, keeping kept: UIGestureRecognizer?) {
        nav.interactivePopGestureRecognizer?.isEnabled = false
        for gesture in nav.view.gestureRecognizers ?? [] {
            if gesture === kept { continue }
            if gesture.name == "splick.chat.edgePop" { continue }
            if gesture is UIPanGestureRecognizer || gesture is UIScreenEdgePanGestureRecognizer {
                gesture.isEnabled = false
            }
        }
        func walk(_ view: UIView) {
            let viewName = NSStringFromClass(type(of: view))
            for gesture in view.gestureRecognizers ?? [] {
                if gesture === kept { continue }
                let name = NSStringFromClass(type(of: gesture))
                let isInteriorNavPan =
                    name.contains("ParallaxTransition")
                    || name.contains("NavigationInteractive")
                    || name.contains("SwipeBack")
                    || (name.contains("UINavigation") && gesture is UIPanGestureRecognizer)
                    || (
                        gesture is UIPanGestureRecognizer
                            && !(gesture is UIScreenEdgePanGestureRecognizer)
                            && (viewName.contains("Navigation") || viewName.contains("Parallax"))
                    )
                if isInteriorNavPan {
                    gesture.isEnabled = false
                }
            }
            view.subviews.forEach(walk)
        }
        walk(nav.view)
    }

    private func isInStrictEdgeBand(point: CGPoint, in view: UIView) -> Bool {
        SplickEdgeInteractivePop.isInLeadingEdgeBand(
            x: point.x,
            viewWidth: view.bounds.width,
            isRightToLeft: view.effectiveUserInterfaceLayoutDirection == .rightToLeft,
            edgeWidth: SplickEdgeInteractivePop.resolvedEdgeWidth(for: view, base: edgeWidth)
        )
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let nav = navigationController, nav.viewControllers.count > 1, let view = nav.view else {
            return false
        }
        guard gestureRecognizer.isEnabled else { return false }
        let point = touch.location(in: view)
        if point.y < view.safeAreaInsets.top + 44 {
            return false
        }
        guard isInStrictEdgeBand(point: point, in: view) else {
            touchStartX = .greatestFiniteMagnitude
            return false
        }
        // Avatar / bubble inside the bezel → reply owns the touch.
        let windowPoint = touch.location(in: nil)
        if SplickEdgeInteractivePop.contentOwnsTouch?(windowPoint) == true {
            touchStartX = .greatestFiniteMagnitude
            return false
        }
        touchStartX = point.x
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = navigationController, nav.viewControllers.count > 1, let view = nav.view else {
            return false
        }
        guard touchStartX != .greatestFiniteMagnitude,
              isInStrictEdgeBand(point: CGPoint(x: touchStartX, y: view.bounds.midY), in: view)
        else {
            return false
        }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        let translation = pan.translation(in: view)
        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        // Gate begin so system `handleNavigationTransition:` only starts on a clear
        // outward horizontal — this is what keeps tracking 1:1 (no early `.began`).
        return SplickInteractivePopAxis.isOutwardHorizontalPop(
            translation: translation,
            isRightToLeft: rtl,
            ratio: 1.15,
            minimumHorizontal: 6
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === pan,
              let scrollView = otherGestureRecognizer.view as? UIScrollView else {
            return false
        }
        return otherGestureRecognizer === scrollView.panGestureRecognizer
    }
}

/// Kept only so runtime migration can detect/remove old instances attached to a nav.
private final class SplickDelayedEdgePopPanGestureRecognizer: UIPanGestureRecognizer {}


private enum SplickNavigationLookup {
    static func navigationController(from view: UIView) -> UINavigationController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let nav = current as? UINavigationController {
                return nav
            }
            if let vc = current as? UIViewController, let nav = vc.navigationController {
                return nav
            }
            responder = current.next
        }
        return nil
    }
}

/// Weak reference box for storing `UIGestureRecognizerDelegate` on associated objects
/// without retaining the internal UIKit transition object.
private final class WeakBox: NSObject {
    private(set) weak var value: UIGestureRecognizerDelegate?
    init(_ value: UIGestureRecognizerDelegate) { self.value = value }
}

/// Full-screen back-swipe. `UIScrollView` automatically yields only to a
/// `UIScreenEdgePanGestureRecognizer`, so a normal pan loses in the middle of
/// the screen. This recognizer cannot be prevented by scroll/refresh pans and
/// fails itself once the drag is clearly vertical.
private final class SplickFullScreenPopPanGestureRecognizer: UIPanGestureRecognizer {
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if Self.isScrollLike(preventingGestureRecognizer) { return false }
        return super.canBePrevented(by: preventingGestureRecognizer)
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        if Self.isScrollLike(preventedGestureRecognizer) { return true }
        return super.canPrevent(preventedGestureRecognizer)
    }

    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        let translation = translation(in: view)
        let dx = abs(translation.x)
        let dy = abs(translation.y)
        if dy > 10, dy > dx, state == .possible {
            state = .failed
        }
    }

    static func isScrollLike(_ gesture: UIGestureRecognizer) -> Bool {
        if gesture.view is UIScrollView { return true }
        var current = gesture.view
        while let view = current {
            if view is UIScrollView { return true }
            current = view.superview
        }
        let name = String(describing: type(of: gesture))
        return name.contains("Scroll")
            || name.contains("Refresh")
            || name.contains("UIScrollView")
    }
}

/// One pan per navigation controller. Waits for the system edge pop to fail, then drives
/// the same `handleNavigationTransition:` so zoom stays percent-driven under the finger.
private final class SplickWidePopGesture: NSObject, UIGestureRecognizerDelegate {
    private static var associatedKey: UInt8 = 0

    private weak var navigationController: UINavigationController?
    private var pan: UIPanGestureRecognizer?
    var fraction: CGFloat = 0.25
    var minimumWidth: CGFloat = 0
    /// When true, keep the widened band off (chat needs content area for reply pans).
    private var isForcedDisabled = false
    /// Original `interactivePopGestureRecognizer.delegate` (`_UINavigationInteractiveTransition`).
    /// Captured before any custom delegate replaces it. Used by `bindTargets` fallback.
    private weak var originalPopDelegate: UIGestureRecognizerDelegate?
    /// Fallback only: `UIPercentDrivenInteractiveTransition` + `popViewController`.
    /// SwiftUI `NavigationStack` often ignores that path, so prefer `handleNavigationTransition:`.
    private var manualDriving = false
    /// Active interactive transition, set during a manual-driven pop gesture.
    private(set) var interactiveTransition: UIPercentDrivenInteractiveTransition?
    /// Fallback 1:1 zoom-style tracking (iOS 26-like card dismiss).
    private weak var fallbackFromView: UIView?
    private weak var fallbackToView: UIView?
    private var fallbackCard: UIView?
    private weak var fallbackNavBar: UIView?
    private var didInsertFallbackToView = false
    private var fallbackToViewOriginalSuperview: UIView?
    private var fallbackToViewOriginalIndex = 0
    private var fallbackTranslation: CGPoint = .zero
    private weak var fallbackHiddenSourceView: UIView?
    private var fallbackSourceFrame: CGRect?
    private var fallbackStartFrame: CGRect = .zero
    /// Inner clip view — rounded continuous card; host (`fallbackCard`) carries the shadow.
    private var fallbackClipView: UIView?
    /// Covers the list card so only the finger-held snapshot is visible.
    private var fallbackHoleView: UIView?
    private var fallbackVelocity: CGPoint = .zero
    private var fallbackSettleAnimator: UIViewPropertyAnimator?
    /// Invalidates in-flight `preferOverScrollPans` retries when `attach` runs again.
    private var preferOverScrollGeneration: UInt = 0
    private var pausedScrollViews: [UIScrollView] = []
    /// iOS 18 zoom: leave the leading bezel to the system pop so the morph stays native.
    private var yieldsLeadingEdgeToSystem = false

    static func install(on nav: UINavigationController, fraction: CGFloat, minimumWidth: CGFloat = 0) {
        let owner: SplickWidePopGesture
        if let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickWidePopGesture {
            owner = existing
        } else {
            owner = SplickWidePopGesture()
            // Capture the original pop delegate. Check both the current pop delegate
            // and the previously saved one (saved before SplickNavigationDelegateProxy replaced it).
            if let popDelegate = nav.interactivePopGestureRecognizer?.delegate,
               !(popDelegate is SplickNavigationDelegateProxy),
               !(popDelegate is SplickWidePopGesture),
               !(popDelegate is SplickZoomPopHorizontalGuard) {
                owner.originalPopDelegate = popDelegate
            } else if let saved = recoverOriginalPopDelegate(from: nav) {
                owner.originalPopDelegate = saved
            }
            objc_setAssociatedObject(nav, &associatedKey, owner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        // If the original delegate is still nil, try recovering from saved.
        if owner.originalPopDelegate == nil, let saved = recoverOriginalPopDelegate(from: nav) {
            owner.originalPopDelegate = saved
        }
        owner.isForcedDisabled = false
        owner.fraction = fraction
        owner.minimumWidth = minimumWidth
        owner.attach(to: nav)
    }

    /// Turns off any widened pop band and keeps `refresh` from re-enabling it.
    static func forceDisable(on nav: UINavigationController) {
        let owner: SplickWidePopGesture
        if let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickWidePopGesture {
            owner = existing
        } else {
            owner = SplickWidePopGesture()
            objc_setAssociatedObject(nav, &associatedKey, owner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        owner.isForcedDisabled = true
        owner.navigationController = nav
        owner.pan?.isEnabled = false
        nav.interactivePopGestureRecognizer?.isEnabled = false
    }

    private func leadingPopBand(in view: UIView) -> CGFloat {
        max(view.bounds.width * fraction, minimumWidth)
    }

    private func attach(to nav: UINavigationController) {
        navigationController = nav
        guard let systemPop = nav.interactivePopGestureRecognizer else { return }

        let canPop = nav.viewControllers.count > 1

        // Chat edge-only mode must keep the stock (wide) recognizer off. Refresh used to
        // re-enable it here and steal reply / timestamp pans from ~20pt of the leading edge.
        if isForcedDisabled {
            systemPop.isEnabled = false
            pan?.isEnabled = false
            return
        }

        let usesZoom = splickNavigationUsesZoom(nav)
        let horizontalDominant = SplickHorizontalDominantPopMode.isActive(on: nav)

        let inFlight: Bool = {
            guard let pan else { return false }
            switch pan.state {
            case .began, .changed:
                return true
            default:
                return false
            }
        }()
        if inFlight {
            pan?.isEnabled = canPop
            return
        }

        if pan == nil || !(pan is SplickFullScreenPopPanGestureRecognizer) {
            if let pan {
                pan.view?.removeGestureRecognizer(pan)
            }
            let gesture = SplickFullScreenPopPanGestureRecognizer(
                target: self,
                action: #selector(handleWidePan(_:))
            )
            gesture.name = "splick.detail.widePop"
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = true
            gesture.delaysTouchesBegan = false
            gesture.delegate = self
            nav.view.addGestureRecognizer(gesture)
            pan = gesture
        }

        let tracksOffEdge = systemPopTracksOffEdge(nav)

        if horizontalDominant {
            if tracksOffEdge {
                // iOS 26 zoom already tracks off-edge; a second pan pops on lift.
                manualDriving = false
                yieldsLeadingEdgeToSystem = false
                bindTargets(from: systemPop, onto: pan)
                systemPop.isEnabled = canPop
                pan?.isEnabled = false
                SplickZoomPopHorizontalGuard.refresh(on: nav)
            } else {
                // System pop is edge-only. Drive the same transition from a
                // full-screen pan so swipe-back works from the middle.
                fraction = 1
                SplickZoomPopHorizontalGuard.uninstall(on: nav)
                let keepSystemPop = usesZoom
                yieldsLeadingEdgeToSystem = keepSystemPop
                applyFullScreenPop(on: nav, systemPop: systemPop, canPop: canPop, keepSystemPop: keepSystemPop)
                DispatchQueue.main.async { [weak self, weak nav, weak systemPop] in
                    guard let self, let nav, let systemPop else { return }
                    guard SplickHorizontalDominantPopMode.isActive(on: nav),
                          !systemPopTracksOffEdge(nav) else { return }
                    self.applyFullScreenPop(
                        on: nav,
                        systemPop: systemPop,
                        canPop: nav.viewControllers.count > 1,
                        keepSystemPop: splickNavigationUsesZoom(nav)
                    )
                }
            }
        } else {
            manualDriving = false
            yieldsLeadingEdgeToSystem = false
            bindTargets(from: systemPop, onto: pan)
            systemPop.isEnabled = canPop
            pan?.isEnabled = canPop && !usesZoom
            SplickZoomPopHorizontalGuard.uninstall(on: nav)
        }
    }

    private func applyFullScreenPop(
        on nav: UINavigationController,
        systemPop: UIGestureRecognizer,
        canPop: Bool,
        keepSystemPop: Bool
    ) {
        let flying: Bool = {
            guard let pan else { return false }
            switch pan.state {
            case .began, .changed: return true
            default: return false
            }
        }()
        guard !flying else { return }
        // A non-edge pan bound to `handleNavigationTransition:` often only
        // finishes on lift. Drive the page 1:1 ourselves instead.
        pan?.removeTarget(nil, action: nil)
        pan?.addTarget(self, action: #selector(handleWidePan(_:)))
        manualDriving = false
        yieldsLeadingEdgeToSystem = keepSystemPop
        systemPop.isEnabled = keepSystemPop && canPop
        pan?.isEnabled = canPop
        preferOverScrollPans(on: nav)
    }

    /// Content pans (scroll / PTR) must wait so a horizontal swipe in the middle
    /// of the screen can begin — same as iOS 26 zoom interactive pop.
    /// Walks the whole nav view (detail may not be `visible` yet during push) and
    /// retries after layout so SwiftUI scroll views mounted later also wait.
    private func preferOverScrollPans(on nav: UINavigationController, retryCount: Int = 0) {
        guard let popPan = pan, popPan.isEnabled else { return }
        if retryCount == 0 {
            preferOverScrollGeneration &+= 1
        }
        let generation = preferOverScrollGeneration

        func walk(_ view: UIView) {
            if let scroll = view as? UIScrollView, scroll.panGestureRecognizer !== popPan {
                scroll.panGestureRecognizer.require(toFail: popPan)
            }
            view.subviews.forEach(walk)
        }
        walk(nav.view)

        guard retryCount < 4 else { return }
        let delays: [TimeInterval] = [0.05, 0.15, 0.35, 0.6]
        let delay = delays[min(retryCount, delays.count - 1)]
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak nav] in
            guard let self, let nav, self.preferOverScrollGeneration == generation else { return }
            self.preferOverScrollPans(on: nav, retryCount: retryCount + 1)
        }
    }

    // MARK: - Full-screen pan observer + manual fallback

    @objc private func handleWidePan(_ gesture: UIPanGestureRecognizer) {
        if manualDriving {
            handleManualPop(gesture)
            return
        }
        guard let nav = navigationController, let view = nav.view else { return }
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .began:
            UIView.performWithoutAnimation {
                nav.view.window?.endEditing(true)
            }
            beginFallbackTracking(on: nav)
            updateFallbackTracking(translation: translation, in: view.bounds.size)

        case .changed:
            updateFallbackTracking(translation: translation, in: view.bounds.size)

        case .ended:
            finishFallbackTracking(
                complete: shouldCompleteZoomPop(
                    translation: translation,
                    velocity: gesture.velocity(in: view)
                ),
                velocity: gesture.velocity(in: view),
                on: nav
            )

        case .cancelled, .failed:
            finishFallbackTracking(complete: false, velocity: .zero, on: nav)

        default:
            break
        }
    }

    private func shouldCompleteZoomPop(translation: CGPoint, velocity: CGPoint) -> Bool {
        let distance = hypot(translation.x, translation.y)
        let speed = hypot(velocity.x, velocity.y)
        return distance > 110 || (distance > 36 && speed > 700)
    }

    private func beginFallbackTracking(on nav: UINavigationController) {
        cancelFallbackTracking(removingInsertedView: true)
        guard nav.viewControllers.count > 1,
              let fromView = nav.topViewController?.view,
              let container = nav.view,
              let card = container.snapshotView(afterScreenUpdates: false) else { return }

        let store = SplickZoomPopSourceStore.shared
        store.beginInteractivePop()
        let postId = store.activeDestinationPostId
        var sourceFrame = postId.flatMap { store.sourceFrame(for: $0, in: container) }
        store.hideActiveSource()

        let toVC = nav.viewControllers[nav.viewControllers.count - 2]
        fallbackToViewOriginalSuperview = toVC.view.superview
        if let original = toVC.view.superview {
            fallbackToViewOriginalIndex = original.subviews.firstIndex(of: toVC.view) ?? 0
        }
        toVC.view.frame = container.bounds
        toVC.view.transform = .identity
        container.insertSubview(toVC.view, at: 0)
        didInsertFallbackToView = true
        toVC.view.layoutIfNeeded()

        if let postId {
            if let live = store.sourceFrame(for: postId, in: container) {
                sourceFrame = live
            }
            if let source = store.sourceCardView(for: postId) {
                fallbackHiddenSourceView = source
                source.alpha = 0
            }
        }
        fallbackStartFrame = container.bounds
        fallbackSourceFrame = sourceFrame ?? defaultZoomPopTargetFrame(in: container)

        let host = UIView(frame: container.bounds)
        host.backgroundColor = .clear
        host.layer.masksToBounds = false
        host.layer.shadowColor = UIColor.black.cgColor
        host.layer.shadowRadius = SplickTheme.Shadow.card.radius
        host.layer.shadowOffset = CGSize(width: SplickTheme.Shadow.card.x, height: SplickTheme.Shadow.card.y)
        let clip = UIView(frame: host.bounds)
        clip.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        clip.backgroundColor = .systemBackground
        clip.layer.cornerCurve = .continuous
        clip.clipsToBounds = true
        card.frame = clip.bounds
        card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        clip.addSubview(card)
        host.addSubview(clip)
        container.addSubview(host)
        installSourceHole(in: container, below: host)

        fromView.isHidden = true
        fallbackNavBar = nav.navigationBar
        fallbackNavBar?.alpha = 0

        fallbackFromView = fromView
        fallbackToView = toVC.view
        fallbackCard = host
        fallbackClipView = clip
        fallbackTranslation = .zero
        fallbackVelocity = .zero
    }

    private func defaultZoomPopTargetFrame(in container: UIView) -> CGRect {
        let horizontalPad = SplickTheme.Spacing.md
        let width = max(container.bounds.width - horizontalPad * 2, 1)
        let height = min(max(container.bounds.height * 0.38, 220), 420)
        let y = container.safeAreaInsets.top + SplickTheme.Spacing.lg
        return CGRect(x: horizontalPad, y: y, width: width, height: height)
    }

    private func paddedHoleFrame(_ frame: CGRect) -> CGRect {
        let pad = SplickTheme.Shadow.card.radius + 4
        return frame.insetBy(dx: -pad, dy: -pad)
    }

    private func installSourceHole(in container: UIView, below card: UIView) {
        fallbackHoleView?.removeFromSuperview()
        guard let sourceFrame = fallbackSourceFrame else { return }
        let hole = UIView(frame: paddedHoleFrame(sourceFrame))
        hole.isUserInteractionEnabled = false
        hole.backgroundColor = .systemBackground
        container.insertSubview(hole, belowSubview: card)
        fallbackHoleView = hole
    }

    private func syncSourceHole(in container: UIView) {
        let store = SplickZoomPopSourceStore.shared
        guard let postId = store.activeDestinationPostId,
              let live = store.sourceFrame(for: postId, in: container),
              live.width > 8,
              live.height > 8 else { return }
        fallbackSourceFrame = live
        fallbackHoleView?.frame = paddedHoleFrame(live)
        if fallbackHiddenSourceView == nil, let source = store.sourceCardView(for: postId) {
            fallbackHiddenSourceView = source
            source.alpha = 0
        }
    }

    private func zoomPopProgress(translation: CGPoint, in size: CGSize) -> CGFloat {
        let distance = hypot(translation.x, translation.y)
        return min(1, distance / max(size.width * 0.38, 1))
    }

    /// Visual (on-screen) corner radius matching `splickCard`.
    private func zoomPopCornerRadius(progress: CGFloat) -> CGFloat {
        let radius = SplickTheme.CornerRadius.card
        let t = min(1, max(0, progress / 0.12))
        return radius * (t * t * (3 - 2 * t))
    }

    /// Scale around the view center, then move with the finger. GPU-only.
    private func zoomPopDragTransform(
        translation: CGPoint,
        progress: CGFloat,
        start: CGRect,
        target: CGRect
    ) -> CGAffineTransform {
        let sx = 1 + (target.width / max(start.width, 1) - 1) * progress
        let sy = 1 + (target.height / max(start.height, 1) - 1) * progress
        return CGAffineTransform(translationX: translation.x, y: translation.y)
            .scaledBy(x: max(sx, 0.12), y: max(sy, 0.12))
    }

    private func zoomPopCompletedTransform(start: CGRect, target: CGRect) -> CGAffineTransform {
        let sx = target.width / max(start.width, 1)
        let sy = target.height / max(start.height, 1)
        return CGAffineTransform(
            translationX: target.midX - start.midX,
            y: target.midY - start.midY
        ).scaledBy(x: sx, y: sy)
    }

    private func applyFallbackCardTransform(translation: CGPoint, progress: CGFloat) {
        guard let host = fallbackCard, let clip = fallbackClipView else { return }
        let start = fallbackStartFrame
        let target = fallbackSourceFrame ?? start
        let transform = zoomPopDragTransform(
            translation: translation,
            progress: progress,
            start: start,
            target: target
        )
        let scaleX = max(abs(transform.a), 0.12)
        let visualRadius = zoomPopCornerRadius(progress: progress)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        host.transform = transform
        clip.layer.cornerRadius = visualRadius / scaleX
        clip.layer.borderWidth = progress > 0.02 ? 0.5 / scaleX : 0
        clip.layer.borderColor = UIColor.label.withAlphaComponent(0.05).cgColor
        host.layer.shadowOpacity = Float(0.05 * min(1, progress / 0.16))
        CATransaction.commit()
    }

    private func settleFallbackCard(complete: Bool, completion: @escaping () -> Void) {
        guard let host = fallbackCard, let clip = fallbackClipView else {
            completion()
            return
        }
        let start = fallbackStartFrame
        let target = fallbackSourceFrame ?? start
        let endTransform = complete
            ? zoomPopCompletedTransform(start: start, target: target)
            : .identity
        let endProgress: CGFloat = complete ? 1 : 0
        let scaleX = complete ? max(target.width / max(start.width, 1), 0.12) : 1
        fallbackSettleAnimator?.stopAnimation(true)
        let animator = UIViewPropertyAnimator(
            duration: 0.48,
            controlPoint1: CGPoint(x: 0.05, y: 0.85),
            controlPoint2: CGPoint(x: 0.18, y: 1.0)
        )
        animator.addAnimations {
            host.transform = endTransform
            clip.layer.cornerRadius = self.zoomPopCornerRadius(progress: endProgress) / scaleX
            clip.layer.borderWidth = complete ? 0.5 / scaleX : 0
            host.layer.shadowOpacity = complete ? 0.05 : 0
        }
        animator.addCompletion { _ in
            self.fallbackSettleAnimator = nil
            completion()
        }
        fallbackSettleAnimator = animator
        animator.startAnimation()
    }

    private func updateFallbackTracking(translation: CGPoint, in size: CGSize) {
        fallbackTranslation = translation
        applyFallbackCardTransform(
            translation: translation,
            progress: zoomPopProgress(translation: translation, in: size)
        )
        fallbackToView?.transform = .identity
    }

    private func restoreInsertedToView(
        toView: UIView?,
        originalSuper: UIView?,
        originalIndex: Int,
        inserted: Bool
    ) {
        toView?.transform = .identity
        guard inserted, let toView, let originalSuper else { return }
        let index = min(originalIndex, originalSuper.subviews.count)
        originalSuper.insertSubview(toView, at: index)
    }

    private func finishFallbackTracking(complete: Bool, velocity: CGPoint, on nav: UINavigationController) {
        fallbackVelocity = velocity
        let card = fallbackCard
        let toView = fallbackToView
        let fromView = fallbackFromView
        let navBar = fallbackNavBar
        let inserted = didInsertFallbackToView
        let originalSuper = fallbackToViewOriginalSuperview
        let originalIndex = fallbackToViewOriginalIndex
        let sourceView = fallbackHiddenSourceView

        if complete {
            sourceView?.alpha = 1
            SplickZoomPopChrome.reveal()
            settleFallbackCard(complete: true) {
                DispatchQueue.main.async {
                    let covering = self.fallbackCard
                    let hole = self.fallbackHoleView
                    self.fallbackHoleView = nil
                    covering?.removeFromSuperview()
                    hole?.removeFromSuperview()
                    self.clearFallbackState()
                }
            }
            // Pop on the next turn so the settle transform is already in-flight.
            // Chrome (nav pills, tab bar) lays out under the covering card.
            DispatchQueue.main.async {
                self.restoreInsertedToView(
                    toView: toView,
                    originalSuper: originalSuper,
                    originalIndex: originalIndex,
                    inserted: inserted
                )
                self.didInsertFallbackToView = false
                navBar?.alpha = 1
                UIView.performWithoutAnimation {
                    if nav.viewControllers.count > 1 {
                        nav.popViewController(animated: false)
                    }
                }
                fromView?.isHidden = false
                if let card = self.fallbackCard, card.superview == nil, let container = nav.view {
                    container.addSubview(card)
                }
                if let hole = self.fallbackHoleView, hole.superview == nil,
                   let container = nav.view, let card = self.fallbackCard {
                    container.insertSubview(hole, belowSubview: card)
                }
            }
        } else {
            settleFallbackCard(complete: false) {
                fromView?.isHidden = false
                fromView?.layoutIfNeeded()
                self.teardownFallbackTracking(
                    fromView: fromView,
                    toView: toView,
                    card: card,
                    navBar: navBar,
                    sourceView: sourceView,
                    restoreToView: true,
                    originalSuper: originalSuper,
                    originalIndex: originalIndex,
                    inserted: inserted
                )
            }
        }
    }

    private func teardownFallbackTracking(
        fromView: UIView?,
        toView: UIView?,
        card: UIView?,
        navBar: UIView?,
        sourceView: UIView?,
        restoreToView: Bool,
        originalSuper: UIView?,
        originalIndex: Int,
        inserted: Bool
    ) {
        card?.removeFromSuperview()
        fallbackHoleView?.removeFromSuperview()
        fallbackHoleView = nil
        fromView?.isHidden = false
        navBar?.alpha = 1
        sourceView?.alpha = 1
        SplickZoomPopSourceStore.shared.revealSource()
        SplickZoomPopSourceStore.shared.endInteractivePop()
        if restoreToView, inserted, let toView {
            if let originalSuper {
                let index = min(originalIndex, originalSuper.subviews.count)
                originalSuper.insertSubview(toView, at: index)
            } else {
                toView.removeFromSuperview()
            }
        }
        clearFallbackState()
    }

    private func clearFallbackState() {
        fallbackSettleAnimator?.stopAnimation(true)
        fallbackSettleAnimator = nil
        fallbackFromView = nil
        fallbackToView = nil
        fallbackCard = nil
        fallbackClipView = nil
        fallbackNavBar = nil
        fallbackToViewOriginalSuperview = nil
        fallbackHiddenSourceView = nil
        fallbackSourceFrame = nil
        fallbackStartFrame = .zero
        fallbackHoleView?.removeFromSuperview()
        fallbackHoleView = nil
        didInsertFallbackToView = false
        fallbackTranslation = .zero
        fallbackVelocity = .zero
        SplickZoomPopSourceStore.shared.endInteractivePop()
    }

    private func cancelFallbackTracking(removingInsertedView: Bool) {
        teardownFallbackTracking(
            fromView: fallbackFromView,
            toView: fallbackToView,
            card: fallbackCard,
            navBar: fallbackNavBar,
            sourceView: fallbackHiddenSourceView,
            restoreToView: removingInsertedView,
            originalSuper: fallbackToViewOriginalSuperview,
            originalIndex: fallbackToViewOriginalIndex,
            inserted: didInsertFallbackToView
        )
    }

    /// Last-resort interactive pop when `handleNavigationTransition:` cannot be bound.
    private func handleManualPop(_ pan: UIPanGestureRecognizer) {
        guard let nav = navigationController,
              let view = nav.view else { return }

        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let tx = pan.translation(in: view).x
        let progress = max(0, min(1, (rtl ? -tx : tx) / view.bounds.width))

        switch pan.state {
        case .began:
            UIView.performWithoutAnimation {
                nav.view.window?.endEditing(true)
            }
            pauseScrollViews(under: nav)
            interactiveTransition = UIPercentDrivenInteractiveTransition()
            interactiveTransition?.completionCurve = .easeOut
            nav.popViewController(animated: true)

        case .changed:
            interactiveTransition?.update(progress)

        case .ended, .cancelled:
            restorePausedScrollViews()
            let vx = pan.velocity(in: view).x
            let outwardVelocity = rtl ? -vx : vx
            if pan.state == .cancelled || (progress < 0.33 && outwardVelocity < 100) {
                interactiveTransition?.cancel()
            } else {
                interactiveTransition?.finish()
            }
            interactiveTransition = nil

        case .failed:
            restorePausedScrollViews()
            interactiveTransition?.cancel()
            interactiveTransition = nil

        default:
            break
        }
    }

    private func pauseScrollViews(under nav: UINavigationController) {
        restorePausedScrollViews()
        var found: [UIScrollView] = []
        func walk(_ view: UIView) {
            if let scroll = view as? UIScrollView, scroll.isScrollEnabled {
                found.append(scroll)
            }
            view.subviews.forEach(walk)
        }
        walk(nav.view)
        for scroll in found {
            scroll.isScrollEnabled = false
        }
        pausedScrollViews = found
    }

    private func restorePausedScrollViews() {
        for scroll in pausedScrollViews {
            scroll.isScrollEnabled = true
        }
        pausedScrollViews = []
    }

    /// Returns the active interactive transition if the wide pop is manually driving a pop.
    static func activeInteractiveTransition(on nav: UINavigationController) -> UIPercentDrivenInteractiveTransition? {
        (objc_getAssociatedObject(nav, &associatedKey) as? SplickWidePopGesture)?.interactiveTransition
    }

    /// Whether a manual pop is currently in progress (used to decide whether to return a pop animator).
    static func isManuallyDrivingPop(on nav: UINavigationController) -> Bool {
        guard let g = objc_getAssociatedObject(nav, &associatedKey) as? SplickWidePopGesture else { return false }
        return g.interactiveTransition != nil
    }

    // MARK: - Refresh & delegate preservation

    static func refresh(on nav: UINavigationController) {
        guard let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickWidePopGesture else {
            return
        }
        existing.attach(to: nav)
    }

    /// Saves the original pop delegate if not already captured.
    /// Called from `SplickInteractivePopConfigurator` before replacing `pop.delegate`.
    /// Stores on a separate key so it survives even if the `SplickWidePopGesture` instance
    /// hasn't been created yet.
    static func preserveOriginalPopDelegate(_ delegate: UIGestureRecognizerDelegate, on nav: UINavigationController) {
        // Also update existing instance if present.
        if let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickWidePopGesture,
           existing.originalPopDelegate == nil {
            existing.originalPopDelegate = delegate
        }
        // Always store on nav so a later `install` can pick it up.
        if objc_getAssociatedObject(nav, &savedPopDelegateKey) == nil {
            // Box with NSValue (weak) to avoid retaining the internal UIKit object forever.
            let box = WeakBox(delegate)
            objc_setAssociatedObject(nav, &savedPopDelegateKey, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Recovers the saved original delegate from the nav (if `SplickWidePopGesture` was created after save).
    private static func recoverOriginalPopDelegate(from nav: UINavigationController) -> UIGestureRecognizerDelegate? {
        (objc_getAssociatedObject(nav, &savedPopDelegateKey) as? WeakBox)?.value
    }

    private static var savedPopDelegateKey: UInt8 = 0

    /// Bind the system interactive-pop handler onto our pan without sharing the
    /// `targets` array (sharing would also attach `handleWidePan` to the stock gesture).
    @discardableResult
    private func bindTargets(from systemPop: UIGestureRecognizer, onto pan: UIPanGestureRecognizer?) -> Bool {
        guard let pan else { return false }

        var bound = false
        // Copy the stock interactive-pop targets so `handleNavigationTransition:`
        // scrubs 1:1 under the finger (same as chat edge pop).
        if let targets = systemPop.value(forKey: "targets") {
            pan.setValue(targets, forKey: "targets")
            bound = true
        }

        let selector = NSSelectorFromString("handleNavigationTransition:")
        if !bound {
            let candidates: [AnyObject?] = [
                systemPop.delegate,
                originalPopDelegate,
                navigationController?.value(forKey: "_interactiveTransition") as AnyObject?
            ]
            for candidate in candidates {
                if let target = candidate,
                   isSystemTransitionTarget(target),
                   (target as? NSObject)?.responds(to: selector) == true {
                    pan.addTarget(target, action: selector)
                    bound = true
                    break
                }
            }
        }

        pan.removeTarget(self, action: #selector(handleWidePan(_:)))
        pan.addTarget(self, action: #selector(handleWidePan(_:)))
        return bound
    }

    private func isSystemTransitionTarget(_ target: AnyObject) -> Bool {
        !(target is SplickNavigationDelegateProxy)
            && !(target is SplickWidePopGesture)
            && !(target is SplickZoomPopHorizontalGuard)
            && !(target is SplickStrictEdgePopGesture)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard !isForcedDisabled else { return false }
        guard let nav = navigationController, nav.viewControllers.count > 1, let view = nav.view else {
            return false
        }
        let point = touch.location(in: view)
        if point.y < view.safeAreaInsets.top + 44 {
            return false
        }
        if SplickHorizontalDominantPopMode.isActive(on: nav) {
            if isInsideHorizontalPagerPastStart(touch) {
                return false
            }
            if yieldsLeadingEdgeToSystem,
               SplickEdgeInteractivePop.isInLeadingEdgeBand(
                x: point.x,
                viewWidth: view.bounds.width,
                isRightToLeft: view.effectiveUserInterfaceLayoutDirection == .rightToLeft,
                edgeWidth: SplickEdgeInteractivePop.resolvedEdgeWidth(for: view)
               ) {
                return false
            }
            return true
        }
        let band = leadingPopBand(in: view)
        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        if rtl {
            return point.x >= view.bounds.width - band
        }
        return point.x <= band
    }

    /// Let a media pager keep swiping between photos when it is not on the first item.
    private func isInsideHorizontalPagerPastStart(_ touch: UITouch) -> Bool {
        var current: UIView? = touch.view
        while let view = current {
            if let scroll = view as? UIScrollView {
                let extraWidth = scroll.contentSize.width - scroll.bounds.width
                let isHorizontal = extraWidth > 8
                    && (scroll.isPagingEnabled || scroll.contentSize.height <= scroll.bounds.height + 40)
                if isHorizontal, scroll.contentOffset.x > 8 {
                    return true
                }
            }
            current = view.superview
        }
        return false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !isForcedDisabled else { return false }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let nav = navigationController,
              let view = nav.view,
              nav.viewControllers.count > 1 else {
            return false
        }
        let translation = pan.translation(in: view)
        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        if SplickHorizontalDominantPopMode.isActive(on: nav) {
            return SplickInteractivePopAxis.isOutwardHorizontalPop(
                translation: translation,
                velocity: pan.velocity(in: view),
                isRightToLeft: rtl,
                ratio: 1.15,
                minimumHorizontal: 6
            )
        }
        let outward = rtl ? translation.x < 0 : translation.x > 0
        return outward && abs(translation.x) > abs(translation.y)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === pan else { return false }
        if otherGestureRecognizer === navigationController?.interactivePopGestureRecognizer {
            return false
        }
        return SplickFullScreenPopPanGestureRecognizer.isScrollLike(otherGestureRecognizer)
            || otherGestureRecognizer is UIPanGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }
}

/// Attaches to the hosting `UINavigationController` via an embedded child controller.
/// More reliable than walking the UIView responder chain inside `NavigationStack`.
private struct SplickFastPageSlideInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SplickFastPageSlideHostController {
        SplickFastPageSlideHostController()
    }

    func updateUIViewController(_ uiViewController: SplickFastPageSlideHostController, context: Context) {
        uiViewController.installIfNeeded()
    }
}

private final class SplickFastPageSlideHostController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installIfNeeded()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        installIfNeeded()
    }

    func installIfNeeded() {
        if let nav = navigationController {
            SplickNavigationDelegateProxy.install(on: nav)
            return
        }

        // Fallback for older SwiftUI hosting layouts.
        var responder: UIResponder? = view
        while let current = responder {
            if let nav = current as? UINavigationController {
                SplickNavigationDelegateProxy.install(on: nav)
                return
            }
            responder = current.next
        }
    }
}

private final class SplickNavigationDelegateProxy: NSObject, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    private static var associatedKey: UInt8 = 0

    private weak var navigationController: UINavigationController?
    private weak var original: UINavigationControllerDelegate?
    private var isForwardingDidShow = false
    private var isForwardingWillShow = false

    static func install(on nav: UINavigationController) {
        let proxy: SplickNavigationDelegateProxy
        if let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickNavigationDelegateProxy {
            proxy = existing
        } else {
            proxy = SplickNavigationDelegateProxy()
            objc_setAssociatedObject(
                nav,
                &associatedKey,
                proxy,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        proxy.attach(to: nav)
    }

    private func attach(to nav: UINavigationController) {
        navigationController = nav
        if nav.delegate !== self {
            let current = nav.delegate
            if !(current is SplickNavigationDelegateProxy) {
                original = current
            }
            nav.delegate = self
        }
        enableInteractivePop(on: nav)
    }

    private func enableInteractivePop(on nav: UINavigationController) {
        SplickInteractivePopConfigurator.apply(to: nav, gestureDelegate: self)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        if #available(iOS 18.0, *), usesSystemZoom(operation: operation, from: fromVC, to: toVC) {
            return original?.navigationController?(
                navigationController,
                animationControllerFor: operation,
                from: fromVC,
                to: toVC
            )
        }

        // When the wide pop gesture is manually driving a pop with
        // UIPercentDrivenInteractiveTransition, we must return a pop animator
        // so that `interactionControllerFor` is called.
        if operation == .pop {
            if SplickWidePopGesture.isManuallyDrivingPop(on: navigationController) {
                return SplickSlideAnimator(operation: .pop)
            }
            return nil
        }

        if operation == .push {
            return SplickSlideAnimator(operation: .push)
        }

        return original?.navigationController?(
            navigationController,
            animationControllerFor: operation,
            from: fromVC,
            to: toVC
        )
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        attach(to: navigationController)
        enableInteractivePop(on: navigationController)

        guard !isForwardingWillShow, original !== self else { return }
        isForwardingWillShow = true
        defer { isForwardingWillShow = false }
        original?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        enableInteractivePop(on: navigationController)
        SplickZoomNavigation.clearPending()
        guard !isForwardingDidShow, original !== self else { return }
        isForwardingDidShow = true
        defer { isForwardingDidShow = false }
        original?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        SplickWidePopGesture.activeInteractiveTransition(on: navigationController)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = navigationController,
              gestureRecognizer === nav.interactivePopGestureRecognizer else {
            return true
        }
        return nav.viewControllers.count > 1
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard let nav = navigationController,
              gestureRecognizer === nav.interactivePopGestureRecognizer else {
            return false
        }
        if SplickStrictEdgePopGesture.isInstalled(on: nav) {
            return false
        }
        return otherGestureRecognizer is UIPanGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    func navigationControllerSupportedInterfaceOrientations(
        _ navigationController: UINavigationController
    ) -> UIInterfaceOrientationMask {
        original?.navigationControllerSupportedInterfaceOrientations?(navigationController) ?? .all
    }

    @available(iOS 18.0, *)
    private func usesSystemZoom(
        operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> Bool {
        if operation == .push, SplickZoomNavigation.isPushPending {
            return true
        }
        return hasPreferredTransition(fromVC) || hasPreferredTransition(toVC)
    }

    @available(iOS 18.0, *)
    private func hasPreferredTransition(_ viewController: UIViewController) -> Bool {
        splickViewControllerUsesZoom(viewController)
    }
}

/// Shared pop-gesture setup so zoom screens never race a second pan / custom pop delegate.
private enum SplickInteractivePopConfigurator {
    static func apply(
        to nav: UINavigationController,
        gestureDelegate: UIGestureRecognizerDelegate? = nil,
        retryZoomDetection: Bool = true
    ) {
        guard let pop = nav.interactivePopGestureRecognizer else { return }

        // Chat edge-only mode owns pop — never re-enable the stock wide recognizer.
        if SplickStrictEdgePopGesture.isInstalled(on: nav) {
            SplickStrictEdgePopGesture.refresh(on: nav)
            SplickWidePopGesture.refresh(on: nav)
            return
        }

        let usesZoom = splickNavigationUsesZoom(nav)
        let horizontalDominant = SplickHorizontalDominantPopMode.isActive(on: nav)
        // Full-screen pan owns pop on older iOS. Re-enabling the stock edge
        // recognizer here made middle-of-screen swipes lose to UIScrollView.
        if !(horizontalDominant && !systemPopTracksOffEdge(nav)) {
            pop.isEnabled = nav.viewControllers.count > 1
        }

        if let currentPopDelegate = pop.delegate,
           !(currentPopDelegate is SplickNavigationDelegateProxy),
           !(currentPopDelegate is SplickWidePopGesture),
           !(currentPopDelegate is SplickZoomPopHorizontalGuard),
           !(currentPopDelegate is SplickStrictEdgePopGesture) {
            SplickWidePopGesture.preserveOriginalPopDelegate(currentPopDelegate, on: nav)
        }

        if usesZoom {
            if pop.delegate is SplickNavigationDelegateProxy {
                pop.delegate = nil
            }
            if horizontalDominant, systemPopTracksOffEdge(nav) {
                SplickZoomPopHorizontalGuard.refresh(on: nav)
            }
        } else if let gestureDelegate {
            let waitForZoomCheck = retryZoomDetection && nav.viewControllers.count > 1
            if #available(iOS 18.0, *), waitForZoomCheck {
                if pop.delegate is SplickNavigationDelegateProxy {
                    pop.delegate = nil
                }
            } else {
                pop.delegate = gestureDelegate
            }
        }

        SplickWidePopGesture.refresh(on: nav)

        // `preferredTransition` is often applied one run-loop after `didShow`.
        if #available(iOS 18.0, *), !usesZoom, retryZoomDetection {
            DispatchQueue.main.async { [weak nav, weak gestureDelegate] in
                guard let nav else { return }
                apply(to: nav, gestureDelegate: gestureDelegate, retryZoomDetection: false)
            }
        }
    }
}

private func splickNavigationUsesZoom(_ nav: UINavigationController) -> Bool {
    if SplickZoomNavigation.isPushPending {
        return true
    }
    if #available(iOS 18.0, *) {
        if let top = nav.topViewController, splickViewControllerUsesZoom(top) {
            return true
        }
        if let visible = nav.visibleViewController,
           visible !== nav.topViewController,
           splickViewControllerUsesZoom(visible) {
            return true
        }
    }
    return false
}

/// iOS 26 zoom interactive pop already tracks from off-edge. Older zoom (iOS 18–25)
/// and non-zoom (iOS 17) stay leading-edge only.
private func systemPopTracksOffEdge(_ nav: UINavigationController) -> Bool {
    guard splickNavigationUsesZoom(nav) else { return false }
    return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
}

@available(iOS 18.0, *)
private func splickViewControllerUsesZoom(_ viewController: UIViewController) -> Bool {
    var seen = Set<ObjectIdentifier>()
    var stack = [viewController]
    while let vc = stack.popLast() {
        let id = ObjectIdentifier(vc)
        if seen.contains(id) { continue }
        seen.insert(id)
        if vc.preferredTransition != nil {
            return true
        }
        stack.append(contentsOf: vc.children)
    }
    return false
}

private final class SplickSlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let operation: UINavigationController.Operation

    init(operation: UINavigationController.Operation) {
        self.operation = operation
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        SplickPageSlideMotion.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }

        let container = transitionContext.containerView
        let width = container.bounds.width
        let parallax = width * 0.28

        if operation == .push {
            container.addSubview(toView)
            toView.frame = container.bounds.offsetBy(dx: width, dy: 0)
            fromView.frame = container.bounds
            toView.layoutIfNeeded()
            fromView.layoutIfNeeded()
            UIView.animate(
                withDuration: SplickPageSlideMotion.duration,
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction]
            ) {
                toView.frame = container.bounds
                fromView.frame = container.bounds.offsetBy(dx: -parallax, dy: 0)
            } completion: { _ in
                fromView.frame = container.bounds
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        } else {
            container.insertSubview(toView, belowSubview: fromView)
            toView.frame = container.bounds.offsetBy(dx: -parallax, dy: 0)
            fromView.frame = container.bounds
            UIView.animate(
                withDuration: SplickPageSlideMotion.duration,
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction]
            ) {
                fromView.frame = container.bounds.offsetBy(dx: width, dy: 0)
                toView.frame = container.bounds
            } completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
}
