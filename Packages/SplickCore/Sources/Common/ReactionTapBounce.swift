import SwiftUI

/// Shared tap feedback timing aligned with feed `InlineReactionBar`.
public enum ReactionTapBounce {
    public static let scale: CGFloat = 1.22
    public static let spring = Animation.spring(response: 0.18, dampingFraction: 0.56)
    public static let settleDelay: TimeInterval = 0.22
    public static let commitDelay: TimeInterval = 0.16
}

public extension View {
    func reactionTapBounce(isActive: Bool) -> some View {
        scaleEffect(isActive ? ReactionTapBounce.scale : 1)
            .animation(ReactionTapBounce.spring, value: isActive)
    }
}
