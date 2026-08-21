import SwiftUI
import UIKit

@MainActor
final class MessageReactionAnchorStore {
    static let shared = MessageReactionAnchorStore()
    var frames: [UUID: CGRect] = [:]

    private init() {}

    func frame(for messageId: UUID) -> CGRect? {
        frames[messageId]
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

    final class ProbeView: UIView {
        var messageId: UUID?

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let messageId, bounds.width > 1, bounds.height > 1 else { return }
            let frame = convert(bounds, to: nil)
            Task { @MainActor in
                MessageReactionAnchorStore.shared.frames[messageId] = frame
            }
        }
    }
}
