import SwiftUI
import DesignSystem

/// Inbox row while a peer is typing — three bouncing dots (matches in-thread indicator).
struct ConversationListTypingPreview: View {
    let accessibilityLabel: String

    fileprivate static let dotSize: CGFloat = 7
    fileprivate static let dotSpacing: CGFloat = 3
    fileprivate static let bounceHeight: CGFloat = 4
    fileprivate static let cycleDuration: TimeInterval = 0.48
    fileprivate static let stagger: TimeInterval = 0.14

    var body: some View {
        HStack(spacing: Self.dotSpacing) {
            ForEach(0..<3, id: \.self) { index in
                InboxTypingBounceDot(index: index)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct InboxTypingBounceDot: View {
    let index: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let loop = ConversationListTypingPreview.cycleDuration * 2
            let phase = elapsed.truncatingRemainder(dividingBy: loop)
            let local = (phase + ConversationListTypingPreview.stagger * Double(index))
                .truncatingRemainder(dividingBy: loop)
            let normalized = local / ConversationListTypingPreview.cycleDuration
            let offsetY: CGFloat = normalized <= 1
                ? -ConversationListTypingPreview.bounceHeight * CGFloat(sin(normalized * .pi))
                : 0

            Circle()
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.85))
                .frame(
                    width: ConversationListTypingPreview.dotSize,
                    height: ConversationListTypingPreview.dotSize
                )
                .offset(y: offsetY)
        }
    }
}
