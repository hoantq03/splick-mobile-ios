import UIKit

enum SplickScrollViewLookup {
    /// Prefers the nearest vertical (non-paging-horizontal) `UIScrollView`.
    static func nearestVerticalScrollView(from view: UIView) -> UIScrollView? {
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
