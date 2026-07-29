import SwiftUI
import UIKit

public extension View {
    /// Makes taps inside `ScrollView` / `List` respond immediately.
    ///
    /// UIKit defaults `delaysContentTouches = true`, so the scroll view waits to see if the
    /// gesture is a drag before delivering the touch to buttons — feels like a long-press.
    func splickInstantScrollTaps(_ enabled: Bool = true) -> some View {
        background {
            SplickScrollViewTouchTuningAnchor(delaysContentTouches: !enabled)
        }
    }
}

private struct SplickScrollViewTouchTuningAnchor: UIViewRepresentable {
    var delaysContentTouches: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let delays = delaysContentTouches
        DispatchQueue.main.async {
            guard let scrollView = Self.nearestVerticalScrollView(from: uiView) else { return }
            if scrollView.delaysContentTouches != delays {
                scrollView.delaysContentTouches = delays
            }
            // Keep cancel-on-drag so scrolling still wins once the finger moves.
            if !scrollView.canCancelContentTouches {
                scrollView.canCancelContentTouches = true
            }
        }
    }

    private static func nearestVerticalScrollView(from view: UIView) -> UIScrollView? {
        var preferred: UIScrollView?
        var fallback: UIScrollView?

        func consider(_ scrollView: UIScrollView) {
            if scrollView.isPagingEnabled {
                let wide = scrollView.contentSize.width > scrollView.bounds.width * 1.2
                if wide { return }
            }
            if preferred == nil {
                preferred = scrollView
            } else if fallback == nil {
                fallback = scrollView
            }
        }

        var ancestor: UIView? = view.superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView {
                consider(scrollView)
            }
            for subview in current.subviews {
                enumerateScrollViews(in: subview, visit: consider)
            }
            if preferred != nil { break }
            ancestor = current.superview
        }

        return preferred ?? fallback
    }

    private static func enumerateScrollViews(in root: UIView, visit: (UIScrollView) -> Void) {
        if let scrollView = root as? UIScrollView {
            visit(scrollView)
        }
        for subview in root.subviews {
            enumerateScrollViews(in: subview, visit: visit)
        }
    }
}
