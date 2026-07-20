import SwiftUI

enum MessageReactionTrayMotion {
    static let present = Animation.spring(response: 0.36, dampingFraction: 0.72, blendDuration: 0.04)
    static let dismiss = Animation.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.04)
    /// Wait for dismiss spring to settle before tearing down the overlay.
    static let dismissSettlingDelay: TimeInterval = 0.30
    static let bubblePop = Animation.spring(response: 0.34, dampingFraction: 0.64)
    static let emojiSlot = Animation.spring(response: 0.38, dampingFraction: 0.62)
}
