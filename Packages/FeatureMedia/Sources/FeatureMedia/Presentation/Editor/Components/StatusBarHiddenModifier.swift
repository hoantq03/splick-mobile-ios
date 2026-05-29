import SwiftUI
import UIKit

extension View {
    /// Hides the system status bar (time, signal, Wi‑Fi, battery) while this view is visible.
    func editorStatusBarHidden(_ hidden: Bool = true) -> some View {
        statusBarHidden(hidden)
            .background(StatusBarHiddenController(isHidden: hidden))
    }
}

private struct StatusBarHiddenController: UIViewControllerRepresentable {
    let isHidden: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller(isHidden: isHidden)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.isHidden = isHidden
        uiViewController.refreshStatusBarVisibility()
    }

    final class Controller: UIViewController {
        var isHidden: Bool

        init(isHidden: Bool) {
            self.isHidden = isHidden
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { nil }

        override var prefersStatusBarHidden: Bool { isHidden }

        override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            refreshStatusBarVisibility()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            refreshStatusBarVisibility()
        }

        func refreshStatusBarVisibility() {
            setNeedsStatusBarAppearanceUpdate()
            parent?.setNeedsStatusBarAppearanceUpdate()
            parent?.parent?.setNeedsStatusBarAppearanceUpdate()
        }
    }
}
