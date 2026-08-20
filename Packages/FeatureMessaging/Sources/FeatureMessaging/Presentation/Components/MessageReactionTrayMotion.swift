import SwiftUI

enum MessageReactionTrayMotion {
    /// Options chrome entrance — underdamped so it settles with one soft bounce.
    static let present = Animation.spring(response: 0.42, dampingFraction: 0.60, blendDuration: 0.04)
    /// Fast, over-damped collapse — no oscillation on the way out.
    static let dismiss = Animation.spring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.04)
    /// Wait for dismiss spring to settle before tearing down the overlay.
    static let dismissSettlingDelay: TimeInterval = 0.24
    /// Bubble lifts off the list — snappy, clearly underdamped for a single soft overshoot.
    static let bubblePop = Animation.spring(response: 0.28, dampingFraction: 0.50)
    /// Each emoji slot pops in — same energy as bubblePop, triggers sequentially.
    static let emojiSlot = Animation.spring(response: 0.30, dampingFraction: 0.50)
    /// Delay between the bubble pop and the options chrome appearing (cascade feel).
    static let optionsChromeDelay: TimeInterval = 0.065
}
