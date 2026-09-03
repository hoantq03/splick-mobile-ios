import SwiftUI

enum FeedScrollAnchor {
    static let top = "feedTop"
    static let coordinateSpace = "feedPullScroll"
}

extension View {
    @ViewBuilder
    func feedScrollBounceAlways() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.always, axes: .vertical)
        } else {
            self
        }
    }
}
