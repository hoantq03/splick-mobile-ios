import SwiftUI

/// Reports a view's bounds converted to window (screen) coordinates — reliable for toolbar items.
struct SplickGlobalFrameReader: UIViewRepresentable {
    @Binding var frame: CGRect

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        Task { @MainActor in
            await Task.yield()
            Self.unclipToolbarAncestors(of: uiView)
            guard uiView.window != nil else { return }
            let next = uiView.convert(uiView.bounds, to: nil)
            guard next.width > 1, next.height > 1, next != frame else { return }
            frame = next
        }
    }

    /// Bar button wrappers clip overflowing SwiftUI overlays (notification badges).
    private static func unclipToolbarAncestors(of view: UIView) {
        var current: UIView? = view.superview
        var depth = 0
        while let ancestor = current, depth < 8 {
            if ancestor is UINavigationBar { break }
            let className = NSStringFromClass(type(of: ancestor))
            if className.contains("NavigationBar") { break }
            ancestor.clipsToBounds = false
            ancestor.layer.masksToBounds = false
            current = ancestor.superview
            depth += 1
        }
    }
}

public extension View {
    func splickGlobalFrame(_ frame: Binding<CGRect>) -> some View {
        background {
            SplickGlobalFrameReader(frame: frame)
        }
    }
}
