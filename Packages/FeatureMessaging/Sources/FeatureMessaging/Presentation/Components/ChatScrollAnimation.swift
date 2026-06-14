import SwiftUI

enum ChatScrollAnimation {
    static let bottomAnchor = "chat-thread-bottom"
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.86)

    static let messageInsert = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .opacity
    )
}
