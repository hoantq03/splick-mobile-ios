import SwiftUI

private enum FeedPagerMotion {
    // Match the main tab pager feel.
    static let spring = Animation.spring(response: 0.46, dampingFraction: 0.60, blendDuration: 0.05)
}

// Segment order determines the visual left→right layout.
private let feedSegmentOrder: [FeedContentSegment] = [.streak, .feed, .album]

// Offset-based pager: pure SwiftUI offset animation, no ScrollView engine conflict.
// Supports swipe with DragGesture; spring drives both programmatic and gesture-ended transitions.
struct FeedContentPager<Feed: View, Album: View, Streak: View>: View {
    @Binding var selection: FeedContentSegment
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var album: () -> Album
    @ViewBuilder var streak: () -> Streak

    @State private var pagerIndex: Int = 1           // .feed is at index 1
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let pageCount = CGFloat(feedSegmentOrder.count)

            HStack(spacing: 0) {
                streak().frame(width: width)
                feed()  .frame(width: width)
                album() .frame(width: width)
            }
            .frame(width: width * pageCount, alignment: .leading)
            .offset(x: -CGFloat(pagerIndex) * width + dragOffset)
            // Only spring-animate when not actively dragging (drag provides real-time offset).
            .animation(isDragging ? nil : FeedPagerMotion.spring, value: pagerIndex)
            .animation(isDragging ? nil : FeedPagerMotion.spring, value: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        isDragging = true
                        let resistance: CGFloat = 0.3
                        let raw = value.translation.width
                        let atLeadingEdge = pagerIndex == 0 && raw > 0
                        let atTrailingEdge = pagerIndex == feedSegmentOrder.count - 1 && raw < 0
                        dragOffset = (atLeadingEdge || atTrailingEdge) ? raw * resistance : raw
                    }
                    .onEnded { value in
                        let threshold = width * 0.28
                        let velocityX = value.predictedEndTranslation.width - value.translation.width
                        var newIndex = pagerIndex
                        if value.translation.width < -threshold || velocityX < -200 {
                            newIndex = min(pagerIndex + 1, feedSegmentOrder.count - 1)
                        } else if value.translation.width > threshold || velocityX > 200 {
                            newIndex = max(pagerIndex - 1, 0)
                        }
                        withAnimation(FeedPagerMotion.spring) {
                            dragOffset = 0
                            pagerIndex = newIndex
                        }
                        isDragging = false
                        selection = feedSegmentOrder[newIndex]
                    }
            )
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pagerIndex = feedSegmentOrder.firstIndex(of: selection) ?? 1
        }
        .onChange(of: selection) { newValue in
            let idx = feedSegmentOrder.firstIndex(of: newValue) ?? 1
            guard idx != pagerIndex else { return }
            pagerIndex = idx
        }
    }
}
