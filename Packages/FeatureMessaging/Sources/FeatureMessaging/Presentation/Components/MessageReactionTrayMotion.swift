import SwiftUI

enum MessageReactionTrayMotion {
    /// Options chrome entrance — underdamped for a visible soft bounce on arrival.
    static let present = Animation.spring(response: 0.44, dampingFraction: 0.56, blendDuration: 0.04)
    /// Fast, over-damped collapse — no oscillation on the way out.
    static let dismiss = Animation.spring(response: 0.24, dampingFraction: 0.90, blendDuration: 0.04)
    /// Wait for dismiss spring to settle before tearing down the overlay.
    static let dismissSettlingDelay: TimeInterval = 0.22
    /// Bubble lifts off — liquid-glass character: quick with a clear single overshoot.
    static let bubblePop = Animation.spring(response: 0.26, dampingFraction: 0.44)
    /// Each emoji slot pops in — same physical energy as the bubble pop.
    static let emojiSlot = Animation.spring(response: 0.28, dampingFraction: 0.46)
    /// Gap between the bubble pop and the options chrome (cascade feel).
    static let optionsChromeDelay: TimeInterval = 0.055
}
