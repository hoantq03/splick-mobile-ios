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
}

private struct SplickInteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SplickInteractivePopHostController {
        SplickInteractivePopHostController()
    }

    func updateUIViewController(_ uiViewController: SplickInteractivePopHostController, context: Context) {
        uiViewController.enableIfNeeded()
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
        guard let pop = nav.interactivePopGestureRecognizer else { return }
        pop.isEnabled = nav.viewControllers.count > 1
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
        guard let pop = nav.interactivePopGestureRecognizer else { return }
        pop.isEnabled = nav.viewControllers.count > 1

        // Zoom (iOS 18) owns interactive dismiss. Hijacking the pop delegate
        // or returning a nil interaction controller disables edge swipe-back.
        if #available(iOS 18.0, *), topViewUsesZoom(nav) {
            if pop.delegate === self {
                pop.delegate = nil
            }
            return
        }

        pop.delegate = self
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
        if viewController.preferredTransition != nil {
            return true
        }
        return viewController.children.contains { hasPreferredTransition($0) }
    }

    @available(iOS 18.0, *)
    private func topViewUsesZoom(_ navigationController: UINavigationController) -> Bool {
        guard let top = navigationController.topViewController else { return false }
        return hasPreferredTransition(top)
    }
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
