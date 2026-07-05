import SwiftUI

enum MessageReactionTrayMotion {
    static let present = Animation.spring(response: 0.36, dampingFraction: 0.72, blendDuration: 0.04)
    static let dismiss = Animation.spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.02)
    static let bubblePop = Animation.spring(response: 0.34, dampingFraction: 0.64)
    static let emojiSlot = Animation.spring(response: 0.38, dampingFraction: 0.62)
}
