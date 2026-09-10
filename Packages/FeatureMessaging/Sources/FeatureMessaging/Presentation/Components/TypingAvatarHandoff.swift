import SwiftUI

enum TypingAvatarHandoff {
    /// Shared `matchedGeometryEffect` id — one peer avatar slides between message → typing.
    static let matchedGeometryId = "chat-typing-avatar-handoff"
}
/// Applies matched geometry when a namespace is provided (typing handoff slide).
struct TypingAvatarMatchedGeometry: ViewModifier {
    var namespace: Namespace.ID?
    var isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled, let namespace {
            content.matchedGeometryEffect(id: TypingAvatarHandoff.matchedGeometryId, in: namespace)
        } else {
            content
        }
    }
}
