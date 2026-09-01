import SwiftUI
import UIKit

private struct SuppressKeyboardAutoFocusKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When `true`, OTP and similar fields should not auto-focus (e.g. splash overlay visible).
    public var suppressKeyboardAutoFocus: Bool {
        get { self[SuppressKeyboardAutoFocusKey.self] }
        set { self[SuppressKeyboardAutoFocusKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    public func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    public func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    public func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }

    public func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(FirstAppearModifier(action: action))
    }

    /// Observes `value` and runs `action` with the new value (iOS 16+).
    ///
    /// Use this instead of trailing-closure `onChange(of:)` which resolves to the iOS 17
    /// `onChange(of:initial:_:)` overload when the closure takes two parameters.
    public func onValueChange<V: Equatable>(
        of value: V,
        perform action: @escaping (V) -> Void
    ) -> some View {
        onChange(of: value, perform: action)
    }
}

private struct FirstAppearModifier: ViewModifier {
    let action: () -> Void
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

private struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(DismissKeyboardTapInstaller())
    }
}

/// Installs a UIKit tap recognizer that dismisses the keyboard only when the tap
/// is outside text inputs — so select/copy/paste inside fields keeps focus.
private struct DismissKeyboardTapInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var hostView: UIView?
        private lazy var recognizer: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            return tap
        }()

        func attach(to markerView: UIView) {
            guard let host = Self.resolveHost(from: markerView) else { return }
            if hostView === host, recognizer.view === host { return }
            detach()
            host.addGestureRecognizer(recognizer)
            hostView = host
        }

        private static func resolveHost(from markerView: UIView) -> UIView? {
            var responder: UIResponder? = markerView
            while let current = responder {
                if let viewController = current as? UIViewController, viewController.isViewLoaded {
                    return viewController.view
                }
                responder = current.next
            }

            var node: UIView? = markerView.superview
            var best: UIView?
            while let current = node {
                if current is UIWindow { break }
                if current.bounds.width >= 64, current.bounds.height >= 64 {
                    best = current
                }
                node = current.superview
            }
            return best ?? markerView.superview
        }

        func detach() {
            if let view = recognizer.view {
                view.removeGestureRecognizer(recognizer)
            }
            hostView = nil
        }

        @objc private func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view = touch.view
            while let current = view {
                if Self.shouldKeepKeyboard(for: current) {
                    return false
                }
                view = current.superview
            }
            return true
        }

        /// Text inputs keep the IME; so do buttons (send, composer actions) so
        /// tapping send does not resign first responder.
        private static func shouldKeepKeyboard(for view: UIView) -> Bool {
            if view is UITextField || view is UITextView || view is UISearchBar {
                return true
            }
            if view is UIControl {
                return true
            }
            if view.accessibilityTraits.contains(.button) {
                return true
            }
            let typeName = String(describing: type(of: view))
            return typeName.contains("Button")
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
