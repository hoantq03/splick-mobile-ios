import SwiftUI

struct MessageReactionAnchorFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct MessageReactionFocusContext: Equatable {
    let session: UUID
    let messageId: UUID
    let isOutgoing: Bool
    /// Window-space bubble frame. Convert with `localized(overlayOrigin:)` before layout.
    let frame: CGRect
    let displayMessage: DisplayMessage
    let currentUserId: UUID
    let senderAvatarURL: URL?
    let senderAvatarName: String
    let showsSenderAvatar: Bool

    func localized(overlayOrigin: CGPoint) -> MessageReactionFocusContext {
        MessageReactionFocusContext(
            session: session,
            messageId: messageId,
            isOutgoing: isOutgoing,
            frame: frame.offsetBy(dx: -overlayOrigin.x, dy: -overlayOrigin.y),
            displayMessage: displayMessage,
            currentUserId: currentUserId,
            senderAvatarURL: senderAvatarURL,
            senderAvatarName: senderAvatarName,
            showsSenderAvatar: showsSenderAvatar
        )
    }
}
