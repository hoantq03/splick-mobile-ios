import SwiftUI
import UIKit

@MainActor
final class MessageReactionAnchorStore {
    static let shared = MessageReactionAnchorStore()

    private var probes: [UUID: WeakProbe] = [:]

    private init() {}

    func register(_ view: MessageBubbleAnchorProbe.ProbeView, messageId: UUID) {
        probes[messageId] = WeakProbe(view: view)
    }

    func unregister(messageId: UUID, view: MessageBubbleAnchorProbe.ProbeView) {
        if probes[messageId]?.view === view {
            probes.removeValue(forKey: messageId)
        }
    }

    /// Window-space frame at call time so scroll does not leave stale hit targets.
    func frame(for messageId: UUID) -> CGRect? {
        liveFrame(from: probes[messageId]?.view)
    }

    func liveFrames(visibleIds: Set<UUID>) -> [(id: UUID, frame: CGRect)] {
        probes.compactMap { id, probe in
            guard visibleIds.contains(id), let frame = liveFrame(from: probe.view) else { return nil }
            return (id, frame)
        }
    }

    private func liveFrame(from view: MessageBubbleAnchorProbe.ProbeView?) -> CGRect? {
        guard let view, view.window != nil else { return nil }
        let bounds = view.bounds
        guard bounds.width > 0.5, bounds.height > 0.5 else { return nil }
        return view.convert(bounds, to: nil)
    }

    private struct WeakProbe {
        weak var view: MessageBubbleAnchorProbe.ProbeView?
    }
}

/// Writes bubble frames into a non-Observable store so scroll layout does not invalidate SwiftUI.
struct MessageBubbleAnchorProbe: UIViewRepresentable {
    let messageId: UUID

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.messageId = messageId
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.messageId = messageId
    }

    static func dismantleUIView(_ uiView: ProbeView, coordinator: ()) {
        if let messageId = uiView.messageId {
            MessageReactionAnchorStore.shared.unregister(messageId: messageId, view: uiView)
        }
    }

    final class ProbeView: UIView {
        var messageId: UUID? {
            didSet {
                guard oldValue != messageId else { return }
                if let oldValue {
                    MessageReactionAnchorStore.shared.unregister(messageId: oldValue, view: self)
                }
                registerIfNeeded()
            }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil, let messageId {
                MessageReactionAnchorStore.shared.unregister(messageId: messageId, view: self)
            } else {
                registerIfNeeded()
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            registerIfNeeded()
        }

        private func registerIfNeeded() {
            guard window != nil, let messageId else { return }
            MessageReactionAnchorStore.shared.register(self, messageId: messageId)
        }
    }
}
