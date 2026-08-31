import SwiftUI
import DesignSystem

/// Shared horizontal chrome for incoming thread rows (messages + typing indicator).
enum MessageThreadRowLayout {
    static let rowSideSpacer: CGFloat = 48
    static let accessorySlotWidth: CGFloat = 46
    /// Matches Android `STATUS_TICK_SIZE` + `STATUS_BUBBLE_GAP`.
    static let statusGutter: CGFloat = 24
    static let listHorizontalPadding: CGFloat = 8
    static let statusBubbleGap: CGFloat = 6
    static let bubbleWidthFraction: CGFloat = 0.72
    static let bubbleAbsoluteMaxWidth: CGFloat = 360
    static let bubbleAbsoluteMinWidth: CGFloat = 160
    /// Fallback when the list has not measured yet.
    static let mediaFallbackMaxWidth: CGFloat = 220

    /// Outer message bubble radius (matches Android `BUBBLE_CORNER_RADIUS`).
    static let bubbleCornerRadius: CGFloat = 20
    /// Nested quote card — paired with bubble so corners read as one family.
    static let quoteCornerRadius: CGFloat = 10
    static let quoteAccentWidth: CGFloat = 2.5
    static let quoteAccentCornerRadius: CGFloat = 1.25
    /// Space between quote strip and message body inside the bubble.
    static let quoteBodySpacing: CGFloat = 6
    static let quoteHorizontalPaddingLeading: CGFloat = 6
    static let quoteHorizontalPaddingTrailing: CGFloat = 8
    static let quoteVerticalPadding: CGFloat = 5

    /// Max bubble/media width for a thread **row** (already inside list padding).
    static func contentMaxWidth(forRowWidth rowWidth: CGFloat) -> CGFloat {
        guard rowWidth > 1 else { return mediaFallbackMaxWidth }
        let fraction = rowWidth * bubbleWidthFraction
        let afterGutter = rowWidth - rowSideSpacer - statusGutter
        let floor = min(bubbleAbsoluteMinWidth, rowWidth * 0.55)
        return max(min(min(fraction, afterGutter), bubbleAbsoluteMaxWidth), floor)
    }
    /// Matches `MessageBubble` text bubble padding (`Spacing.sm + 2`, `Spacing.xs + 2`).
    static let bubbleHorizontalPadding: CGFloat = 14
    static let bubbleVerticalPadding: CGFloat = 10
    /// ~single-line body text lane inside the bubble.
    static let bubbleMinContentHeight: CGFloat = 22
    static var typingBubbleMinHeight: CGFloat {
        bubbleVerticalPadding * 2 + bubbleMinContentHeight
    }
}

extension VerticalAlignment {
    private struct MessageThreadRowCenterAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let messageThreadRowCenter = VerticalAlignment(MessageThreadRowCenterAlignment.self)
}

/// Collapsed timestamp slot — matches incoming `MessageBubble` at rest (0pt revealed width).
struct MessageThreadIncomingLeadingSlot: View {
    var body: some View {
        Text("00:00")
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: MessageThreadRowLayout.accessorySlotWidth, alignment: .trailing)
            .frame(width: 0, alignment: .trailing)
            .clipped()
            .alignmentGuide(.messageThreadRowCenter) { dimensions in
                dimensions[VerticalAlignment.center]
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

struct MessageThreadIncomingRow<Content: View>: View {
    let topSpacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .messageThreadRowCenter, spacing: SplickTheme.Spacing.xxs) {
            MessageThreadIncomingLeadingSlot()
            content()
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: MessageThreadRowLayout.rowSideSpacer)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, topSpacing)
    }
}
