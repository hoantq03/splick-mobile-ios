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
            guard let scrollView = SplickScrollViewLookup.nearestVerticalScrollView(from: uiView) else { return }
            if scrollView.delaysContentTouches != delays {
                scrollView.delaysContentTouches = delays
            }
            // Keep cancel-on-drag so scrolling still wins once the finger moves.
            if !scrollView.canCancelContentTouches {
                scrollView.canCancelContentTouches = true
            }
        }
    }
}
