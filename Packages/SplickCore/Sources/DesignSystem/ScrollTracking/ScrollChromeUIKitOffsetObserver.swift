import SwiftUI
import UIKit

/// iOS 16–17 scroll-offset probe. Attaches to the enclosing `UIScrollView` via KVO
/// so chrome can update without a per-frame SwiftUI `PreferenceKey` layout pass.
struct ScrollChromeUIKitOffsetObserver: UIViewRepresentable {
    var isEnabled: Bool
    var onOffsetChange: (CGFloat) -> Void
    var onIdle: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onOffsetChange = onOffsetChange
        context.coordinator.onIdle = onIdle
        DispatchQueue.main.async {
            context.coordinator.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var isEnabled = true
        var onOffsetChange: ((CGFloat) -> Void)?
        var onIdle: (() -> Void)?

        private weak var scrollView: UIScrollView?
        private var offsetObservation: NSKeyValueObservation?
        private var draggingObservation: NSKeyValueObservation?
        private var deceleratingObservation: NSKeyValueObservation?
        private var lastReportedOffset: CGFloat?
        private let deltaGate: CGFloat = 0.25

        func attach(from probe: UIView) {
            guard let found = SplickScrollViewLookup.nearestVerticalScrollView(from: probe) else { return }
            guard found !== scrollView else { return }
            detach()
            scrollView = found
            offsetObservation = found.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                self?.handleOffsetChange(in: scrollView)
            }
            draggingObservation = found.observe(\.isDragging, options: [.new]) { [weak self] scrollView, _ in
                self?.handleIdleIfNeeded(in: scrollView)
            }
            deceleratingObservation = found.observe(\.isDecelerating, options: [.new]) { [weak self] scrollView, _ in
                self?.handleIdleIfNeeded(in: scrollView)
            }
            handleOffsetChange(in: found)
        }

        func detach() {
            offsetObservation?.invalidate()
            draggingObservation?.invalidate()
            deceleratingObservation?.invalidate()
            offsetObservation = nil
            draggingObservation = nil
            deceleratingObservation = nil
            scrollView = nil
            lastReportedOffset = nil
        }

        private func handleOffsetChange(in scrollView: UIScrollView) {
            guard isEnabled else { return }
            let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            if let lastReportedOffset, abs(offset - lastReportedOffset) < deltaGate {
                return
            }
            lastReportedOffset = offset
            onOffsetChange?(offset)
        }

        private func handleIdleIfNeeded(in scrollView: UIScrollView) {
            guard isEnabled else { return }
            guard !scrollView.isDragging, !scrollView.isDecelerating else { return }
            let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            lastReportedOffset = offset
            onOffsetChange?(offset)
            onIdle?()
        }
    }
}

extension View {
    func scrollChromeUIKitOffsetTracking(
        isEnabled: Bool,
        onOffsetChange: @escaping (CGFloat) -> Void,
        onIdle: (() -> Void)? = nil
    ) -> some View {
        background {
            ScrollChromeUIKitOffsetObserver(
                isEnabled: isEnabled,
                onOffsetChange: onOffsetChange,
                onIdle: onIdle
            )
        }
    }
}
