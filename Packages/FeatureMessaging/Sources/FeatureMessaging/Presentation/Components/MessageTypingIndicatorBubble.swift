import SwiftUI
import DesignSystem
import Localization

/// Inline peer typing row — incoming bubble with three bouncing dots.
struct MessageTypingIndicatorBubble: View {
    @EnvironmentObject private var languageService: LanguageService

    private static let bubbleCornerRadius: CGFloat = 24
    fileprivate static let dotSize: CGFloat = 7
    private static let dotSpacing: CGFloat = 3
    fileprivate static let bounceHeight: CGFloat = 4
    fileprivate static let cycleDuration: TimeInterval = 0.48
    fileprivate static let stagger: TimeInterval = 0.14

    var body: some View {
        MessageThreadIncomingRow(topSpacing: SplickTheme.Spacing.sm) {
            HStack(spacing: Self.dotSpacing) {
                ForEach(0..<3, id: \.self) { index in
                    TypingDot(index: index)
                }
            }
            .padding(.top, Self.bounceHeight)
            .frame(minHeight: MessageThreadRowLayout.bubbleMinContentHeight)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, MessageThreadRowLayout.bubbleHorizontalPadding)
            .padding(.vertical, MessageThreadRowLayout.bubbleVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: Self.bubbleCornerRadius, style: .continuous)
                    .fill(SplickTheme.Colors.secondaryBackground)
            )
            .frame(minHeight: MessageThreadRowLayout.typingBubbleMinHeight)
        }
        .accessibilityLabel(languageService.text(.messagingChatTyping))
    }
}

private struct TypingDot: View {
    let index: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let loop = MessageTypingIndicatorBubble.cycleDuration * 2
            let phase = elapsed.truncatingRemainder(dividingBy: loop)
            let local = (phase + MessageTypingIndicatorBubble.stagger * Double(index))
                .truncatingRemainder(dividingBy: loop)
            let normalized = local / MessageTypingIndicatorBubble.cycleDuration
            let offsetY: CGFloat = normalized <= 1
                ? -MessageTypingIndicatorBubble.bounceHeight * CGFloat(sin(normalized * .pi))
                : 0

            Circle()
                .fill(SplickTheme.Colors.textSecondary.opacity(0.72))
                .frame(
                    width: MessageTypingIndicatorBubble.dotSize,
                    height: MessageTypingIndicatorBubble.dotSize
                )
                .offset(y: offsetY)
        }
    }
}
