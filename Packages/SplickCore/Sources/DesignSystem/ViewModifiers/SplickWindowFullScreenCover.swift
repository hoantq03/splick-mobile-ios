import SwiftUI
import UIKit

/// Presents a true window-level full-screen cover.
///
/// SwiftUI `.fullScreenCover` on an iOS 18 `navigationTransition(.zoom)` destination
/// (and some nested stacks) stays inside the zoom/nav container, so the parent header
/// remains visible. This modifier presents from the key window instead.
///
/// The overlay is a new `UIHostingController`, so it does not inherit `@EnvironmentObject`
/// unless we copy `EnvironmentValues` from the presenting SwiftUI tree.
public extension View {
    func splickWindowFullScreenCover<Item: Identifiable>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        background(
            SplickWindowFullScreenCoverHost(
                item: item,
                content: content
            )
        )
    }

    func splickWindowFullScreenCover(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        splickWindowFullScreenCover(
            item: Binding(
                get: { isPresented.wrappedValue ? SplickPresentedFlag() : nil },
                set: { isPresented.wrappedValue = $0 != nil }
            ),
            content: { _ in content() }
        )
    }
}

private struct SplickPresentedFlag: Identifiable {
    var id: Bool { true }
}

private struct SplickEnvironmentInjectedContent<Content: View>: View {
    var environment: EnvironmentValues
    var content: Content

    var body: some View {
        content.environment(\.self, environment)
    }
}

private struct SplickWindowFullScreenCoverHost<Item: Identifiable, Content: View>: UIViewControllerRepresentable {
    @Binding var item: Item?
    let content: (Item) -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {}

    func makeUIViewController(context: Context) -> SplickWindowFullScreenCoverController<Item, Content> {
        SplickWindowFullScreenCoverController()
    }

    func updateUIViewController(
        _ uiViewController: SplickWindowFullScreenCoverController<Item, Content>,
        context: Context
    ) {
        uiViewController.swiftUIEnvironment = context.environment
        uiViewController.contentBuilder = content
        uiViewController.setItem(item) {
            item = nil
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: SplickWindowFullScreenCoverController<Item, Content>,
        coordinator: Coordinator
    ) {
        uiViewController.teardown(animated: false)
    }
}

private final class SplickWindowFullScreenCoverController<Item: Identifiable, Content: View>: UIViewController {
    var contentBuilder: ((Item) -> Content)?
    var swiftUIEnvironment = EnvironmentValues()
    private var presentedItemID: Item.ID?
    private var hosted: SplickWindowOverlayHostingController<SplickEnvironmentInjectedContent<Content>>?
    private var onDismissFromUI: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    func setItem(_ item: Item?, onDismiss: @escaping () -> Void) {
        onDismissFromUI = onDismiss
        switch (item, presentedItemID) {
        case let (item?, id?) where item.id == id:
            if let hosted, let root = injectedRoot(for: item) {
                hosted.rootView = root
            }
        case let (item?, _):
            presentItem(item, onDismiss: onDismiss)
        case (nil, .some):
            teardown(animated: true)
        default:
            break
        }
    }

    func teardown(animated: Bool) {
        presentedItemID = nil
        guard let hosted else { return }
        self.hosted = nil
        hosted.onDismissed = nil
        if hosted.presentingViewController != nil {
            hosted.dismiss(animated: animated)
        } else {
            hosted.view.removeFromSuperview()
            hosted.removeFromParent()
        }
    }

    private func injectedRoot(for item: Item) -> SplickEnvironmentInjectedContent<Content>? {
        guard let builder = contentBuilder else { return nil }
        return SplickEnvironmentInjectedContent(
            environment: swiftUIEnvironment,
            content: builder(item)
        )
    }

    private func presentItem(_ item: Item, onDismiss: @escaping () -> Void) {
        guard let root = injectedRoot(for: item) else { return }
        teardown(animated: false)

        let host = SplickWindowOverlayHostingController(rootView: root)
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        host.modalPresentationCapturesStatusBarAppearance = true
        host.view.backgroundColor = .black
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.onDismissed = { [weak self] in
            guard let self, self.presentedItemID != nil else { return }
            self.presentedItemID = nil
            self.hosted = nil
            onDismiss()
        }

        presentedItemID = item.id
        hosted = host

        if let presenter = SplickWindowPresenter.topViewController(from: view) {
            presenter.present(host, animated: true)
        } else if let window = SplickWindowPresenter.keyWindow(from: view) {
            host.view.frame = window.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.view.insetsLayoutMarginsFromSafeArea = false
            window.addSubview(host.view)
        }
    }
}

private final class SplickWindowOverlayHostingController<Content: View>: UIHostingController<Content> {
    var onDismissed: (() -> Void)?

    override var prefersStatusBarHidden: Bool { true }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || (presentingViewController == nil && view.superview == nil) {
            onDismissed?()
        }
    }
}

private enum SplickWindowPresenter {
    static func keyWindow(from view: UIView) -> UIWindow? {
        if let window = view.window { return window }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    static func topViewController(from view: UIView) -> UIViewController? {
        guard let window = keyWindow(from: view) else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
