import CoreGraphics
import Foundation

/// Pure hit-geometry for chat horizontal pans (reply vs edge-pop zones).
enum ChatSwipeHitTesting {
    /// Soft padding around the bubble probe frame (matches prior messageHit insets).
    static let bubbleHitInsetX: CGFloat = 14
    static let bubbleHitInsetY: CGFloat = 10

    /// Expanded hit frame used to classify swipe-to-reply.
    /// Incoming includes the avatar gutter so fingers starting on the avatar still reply.
    static func replyHitFrame(
        bubbleFrame: CGRect,
        isOutgoing: Bool,
        isRightToLeft: Bool,
        avatarGutter: CGFloat
    ) -> CGRect {
        var frame = bubbleFrame.insetBy(dx: -bubbleHitInsetX, dy: -bubbleHitInsetY)
        guard !isOutgoing, avatarGutter > 0 else { return frame }

        if isRightToLeft {
            frame.size.width += avatarGutter
        } else {
            frame.origin.x -= avatarGutter
            frame.size.width += avatarGutter
        }
        return frame
    }
}
