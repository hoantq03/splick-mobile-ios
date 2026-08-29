import SwiftUI

enum ChatScrollAnimation {
    static let bottomAnchor = "chat-thread-bottom"
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let jumpToMessage = Animation.spring(response: 0.26, dampingFraction: 0.9)
    /// Noticeable hop: scale + lift, snappy so it does not wait on scroll.
    static let highlightPeakScale: CGFloat = 1.25
    static let highlightLift: CGFloat = -12
    static let highlightPop = Animation.spring(response: 0.22, dampingFraction: 0.48)
    static let highlightSettle = Animation.spring(response: 0.34, dampingFraction: 0.7)

    static let messageInsert = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .opacity
    )
}
