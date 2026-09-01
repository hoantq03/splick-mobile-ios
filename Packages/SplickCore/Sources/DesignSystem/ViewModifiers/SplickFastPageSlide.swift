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

    /// System edge swipe-back only. Disables the stock (wide) interactive-pop recognizer
    /// and any widened pop band, then installs a thin leading-edge pan for chat reply screens.
    public func splickEdgeOnlyInteractivePop(edgeWidth: CGFloat = 1) -> some View {
        background(SplickEdgeOnlyInteractivePopInstaller(edgeWidth: edgeWidth))
    }

    /// Widens interactive pop to the leading quarter of the screen (same as Android post detail).
    /// On iOS 18 zoom destinations (feed → post) the extra pan is disabled — zoom dismiss is
    /// bound to the system edge gesture, and a second pan only pops after the finger lifts.
    public func splickWideInteractivePop(fraction: CGFloat = 0.25, minimumWidth: CGFloat = 0) -> some View {
        background(SplickWideInteractivePopInstaller(fraction: fraction, minimumWidth: minimumWidth))
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
    var edgeWidth: CGFloat = 1

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
        guard let nav = navigationController ?? ancestorNavigationController() else { return }
        SplickStrictEdgePopGesture.install(on: nav, edgeWidth: edgeWidth)
    }

    func restoreSystemPopIfNeeded() {
        guard let nav = navigationController ?? ancestorNavigationController() else { return }
        SplickStrictEdgePopGesture.uninstall(on: nav)
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

/// Thin leading-edge pop used by chat. Disables stock interactive-pop (too wide) and
/// drives the same transition targets from a hairline leading strip only.
private final class SplickStrictEdgePopGesture: NSObject, UIGestureRecognizerDelegate {
    private static var associatedKey: UInt8 = 0

    private weak var navigationController: UINavigationController?
    private var pan: UIPanGestureRecognizer?
    var edgeWidth: CGFloat = 1
    private var touchStartX: CGFloat = .greatestFiniteMagnitude

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

    private func attach(to nav: UINavigationController) {
        navigationController = nav
        guard let systemPop = nav.interactivePopGestureRecognizer else { return }

        SplickWidePopGesture.forceDisable(on: nav)

        // Stock recognizer accepts a wide leading band and steals chat reply pans.
        systemPop.isEnabled = false

        if pan == nil {
            let gesture = UIPanGestureRecognizer()
            gesture.maximumNumberOfTouches = 1
            gesture.delegate = self
            nav.view.addGestureRecognizer(gesture)
            pan = gesture
        }

        bindTargets(from: systemPop, onto: pan)
        pan?.isEnabled = nav.viewControllers.count > 1
    }

    private func detach(restoringSystemPop: Bool) {
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
        if let targets = systemPop.value(forKey: "targets") {
            pan.setValue(targets, forKey: "targets")
            return
        }
        let selector = NSSelectorFromString("handleNavigationTransition:")
        if let transition = systemPop.delegate, transition.responds(to: selector) {
            pan.addTarget(transition, action: selector)
        }
    }

    private func isInStrictEdgeBand(point: CGPoint, in view: UIView) -> Bool {
        if view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            return point.x >= view.bounds.width - edgeWidth
        }
        return point.x <= edgeWidth
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let nav = navigationController, nav.viewControllers.count > 1, let view = nav.view else {
            return false
        }
        let point = touch.location(in: view)
        if point.y < view.safeAreaInsets.top + 44 {
            return false
        }
        guard isInStrictEdgeBand(point: point, in: view) else {
            touchStartX = .greatestFiniteMagnitude
            return false
        }
        touchStartX = point.x
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let nav = navigationController,
              let view = nav.view,
              nav.viewControllers.count > 1 else {
            return false
        }
        // Re-check start location — `shouldReceive` alone is not enough if another
        // recognizer path reuses this pan after a non-edge touch.
        let start = pan.location(in: view)
        let edgePoint = CGPoint(x: touchStartX, y: start.y)
        guard isInStrictEdgeBand(point: edgePoint, in: view) || isInStrictEdgeBand(point: start, in: view) else {
            return false
        }
        let translation = pan.translation(in: view)
        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let outward = rtl ? translation.x < 0 : translation.x > 0
        return outward && abs(translation.x) > abs(translation.y)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
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

    static func install(on nav: UINavigationController, fraction: CGFloat, minimumWidth: CGFloat = 0) {
        let owner: SplickWidePopGesture
        if let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickWidePopGesture {
            owner = existing
        } else {
            owner = SplickWidePopGesture()
            objc_setAssociatedObject(nav, &associatedKey, owner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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

        systemPop.isEnabled = canPop

        if pan == nil {
            let gesture = UIPanGestureRecognizer()
            gesture.maximumNumberOfTouches = 1
            gesture.delegate = self
            nav.view.addGestureRecognizer(gesture)
            pan = gesture
        }

        bindTargets(from: systemPop, onto: pan)

        let usesZoom = splickNavigationUsesZoom(nav)
        // Zoom interactive dismiss is bound to the system edge recognizer.
        // A second pan with copied targets pops on lift instead of tracking the finger.
        pan?.isEnabled = canPop && !usesZoom
    }

    static func refresh(on nav: UINavigationController) {
        guard let existing = objc_getAssociatedObject(nav, &associatedKey) as? SplickWidePopGesture else {
            return
        }
        existing.attach(to: nav)
    }

    private func bindTargets(from systemPop: UIGestureRecognizer, onto pan: UIPanGestureRecognizer?) {
        guard let pan else { return }
        if let targets = systemPop.value(forKey: "targets") {
            pan.setValue(targets, forKey: "targets")
            return
        }
        let selector = NSSelectorFromString("handleNavigationTransition:")
        if let transition = systemPop.delegate, transition.responds(to: selector) {
            pan.addTarget(transition, action: selector)
        }
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
        let band = leadingPopBand(in: view)
        if view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            return point.x >= view.bounds.width - band
        }
        return point.x <= band
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
        let outward = rtl ? translation.x < 0 : translation.x > 0
        return outward && abs(translation.x) > abs(translation.y)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer === navigationController?.interactivePopGestureRecognizer
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

        // Custom pop animators suppress UIKit's percent-driven edge swipe. Keep
        // the system interactive pop; only accelerate programmatic pushes.
        if operation == .pop {
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

        pop.isEnabled = nav.viewControllers.count > 1

        let usesZoom = splickNavigationUsesZoom(nav)
        if usesZoom {
            if pop.delegate is SplickNavigationDelegateProxy {
                pop.delegate = nil
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
