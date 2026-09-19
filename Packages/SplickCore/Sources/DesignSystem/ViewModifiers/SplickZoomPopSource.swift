import SwiftUI
import UIKit
import Combine

/// Tracks the feed card that a post-detail zoom pop should morph back into.
/// Main-thread only.
public final class SplickZoomPopSourceStore: ObservableObject {
    public static let shared = SplickZoomPopSourceStore()

    /// True while a custom zoom-pop snapshot covers the feed. Polls and other
    /// SwiftUI publishes must wait so they do not hitch the landing frame.
    public private(set) var isInteractivePopInProgress = false
    public private(set) var activeDestinationPostId: UUID?

    private var anchors: [UUID: WeakViewBox] = [:]
    /// Window-space frames kept after the feed leaves the window so pop can
    /// still morph into the empty list slot.
    private var windowFrames: [UUID: CGRect] = [:]

    private init() {}

    public func setActiveDestination(_ postId: UUID?) {
        activeDestinationPostId = postId
    }

    public func beginInteractivePop() {
        isInteractivePopInProgress = true
    }

    public func endInteractivePop() {
        isInteractivePopInProgress = false
    }

    /// UIKit hides the source card (`alpha` + hole). Do not publish here —
    /// `@Published` would invalidate every feed cell during the gesture.
    public func hideActiveSource() {}

    public func revealSource() {}

    public func registerAnchor(_ view: UIView, postId: UUID) {
        for (id, box) in anchors where id != postId && box.value === view {
            anchors[id] = nil
        }
        anchors[postId] = WeakViewBox(view)
        rememberFrame(of: view, postId: postId)
    }

    public func unregisterAnchor(_ view: UIView, postId: UUID) {
        if anchors[postId]?.value === view {
            anchors[postId] = nil
        }
    }

    public func sourceAnchor(for postId: UUID) -> UIView? {
        anchors[postId]?.value
    }

    /// Card frame in `target` coordinates. Prefers the live anchor; otherwise
    /// the last on-screen window frame captured before push.
    public func sourceFrame(for postId: UUID, in target: UIView) -> CGRect? {
        if let anchor = sourceAnchor(for: postId),
           anchor.window != nil,
           anchor.bounds.width > 8,
           anchor.bounds.height > 8 {
            let live = anchor.convert(anchor.bounds, to: target)
            if live.width > 8, live.height > 8 {
                rememberFrame(of: anchor, postId: postId)
                return live
            }
        }
        guard let stored = windowFrames[postId] else { return nil }
        if let window = target.window {
            let converted = window.convert(stored, to: target)
            if converted.width > 8, converted.height > 8 {
                return converted
            }
        }
        return stored.width > 8 && stored.height > 8 ? stored : nil
    }

    /// Same-sized chrome around the anchor — never the whole feed list.
    public func sourceCardView(for postId: UUID) -> UIView? {
        guard let anchor = sourceAnchor(for: postId) else { return nil }
        let target = anchor.bounds
        guard target.width > 8, target.height > 8 else { return nil }
        var current: UIView? = anchor.superview
        var best = anchor
        while let view = current {
            if view is UIScrollView || view is UIWindow { break }
            let size = view.bounds
            let widthMatch = abs(size.width - target.width) <= 32
            let heightMatch = size.height >= target.height - 8
                && size.height <= target.height * 1.4
            if widthMatch && heightMatch {
                best = view
            }
            current = view.superview
        }
        return best
    }

    private func rememberFrame(of view: UIView, postId: UUID) {
        guard view.window != nil, view.bounds.width > 8, view.bounds.height > 8 else { return }
        windowFrames[postId] = view.convert(view.bounds, to: nil)
    }
}

private final class WeakViewBox {
    weak var value: UIView?
    init(_ value: UIView) { self.value = value }
}

/// Invisible probe behind a feed card so interactive pop can find its frame.
public struct SplickZoomPopSourceAnchor: UIViewRepresentable {
    let postId: UUID

    public init(postId: UUID) {
        self.postId = postId
    }

    public func makeUIView(context: Context) -> SplickZoomPopAnchorView {
        let view = SplickZoomPopAnchorView()
        view.postId = postId
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }

    public func updateUIView(_ uiView: SplickZoomPopAnchorView, context: Context) {
        if uiView.postId != postId, let old = uiView.postId {
            SplickZoomPopSourceStore.shared.unregisterAnchor(uiView, postId: old)
        }
        uiView.postId = postId
        SplickZoomPopSourceStore.shared.registerAnchor(uiView, postId: postId)
    }

    public static func dismantleUIView(_ uiView: SplickZoomPopAnchorView, coordinator: ()) {
        if let postId = uiView.postId {
            SplickZoomPopSourceStore.shared.unregisterAnchor(uiView, postId: postId)
        }
    }
}

public final class SplickZoomPopAnchorView: UIView {
    public var postId: UUID?

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let postId else { return }
        if window == nil {
            SplickZoomPopSourceStore.shared.unregisterAnchor(self, postId: postId)
        } else {
            SplickZoomPopSourceStore.shared.registerAnchor(self, postId: postId)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if let postId {
            SplickZoomPopSourceStore.shared.registerAnchor(self, postId: postId)
        }
    }
}

/// Marks the visible post-detail destination as the active zoom-pop target.
public struct SplickZoomPopDestinationAnchor: UIViewRepresentable {
    let postId: UUID

    public init(postId: UUID) {
        self.postId = postId
    }

    public func makeUIView(context: Context) -> SplickZoomPopDestinationView {
        let view = SplickZoomPopDestinationView()
        view.postId = postId
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    public func updateUIView(_ uiView: SplickZoomPopDestinationView, context: Context) {
        uiView.postId = postId
        SplickZoomPopSourceStore.shared.setActiveDestination(postId)
    }

    public static func dismantleUIView(_ uiView: SplickZoomPopDestinationView, coordinator: ()) {
        if SplickZoomPopSourceStore.shared.activeDestinationPostId == uiView.postId {
            SplickZoomPopSourceStore.shared.setActiveDestination(nil)
        }
    }
}

public final class SplickZoomPopDestinationView: UIView {
    public var postId: UUID?

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, let postId {
            SplickZoomPopSourceStore.shared.setActiveDestination(postId)
        } else if SplickZoomPopSourceStore.shared.activeDestinationPostId == postId {
            SplickZoomPopSourceStore.shared.setActiveDestination(nil)
        }
    }
}
