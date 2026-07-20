import SwiftUI
import UIKit
import DesignSystem
import Localization

struct MessageReactionFocusOverlay: View {
    @EnvironmentObject private var languageService: LanguageService

    let context: MessageReactionFocusContext
    let onReact: (String) -> Void
    let onReply: () -> Void
    let onOpenFullPicker: () -> Void
    let onDismiss: () -> Void

    @State private var isRevealed = false
    @State private var optionsSize: CGSize = CGSize(width: 200, height: 88)
    @State private var messageSize: CGSize = CGSize(width: 160, height: 44)

    /// Same gap between reply ↔ emoji ↔ message.
    private let stackSpacing: CGFloat = 10
    /// Equal leading/trailing inset — shared by message and options.
    private let horizontalMargin: CGFloat = SplickTheme.Spacing.lg
    private let verticalMargin: CGFloat = SplickTheme.Spacing.md
    /// In-place pop — message stays put and grows toward the viewer.
    private let messageFocusScale: CGFloat = 1.12
    private static let replyImpact = UIImpactFeedbackGenerator(style: .light)

    private var contentAlignment: Alignment {
        context.isOutgoing ? .trailing : .leading
    }

    private var horizontalAlignment: HorizontalAlignment {
        context.isOutgoing ? .trailing : .leading
    }

    /// Keep the aligned edge fixed while scaling (matches options column).
    private var horizontalScaleAnchorX: CGFloat {
        context.isOutgoing ? 1 : 0
    }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = max(geo.size.width - horizontalMargin * 2, 120)
            let placeOptionsAbove = shouldPlaceOptionsAbove(
                containerHeight: geo.size.height,
                optionsHeight: optionsSize.height
            )

            ZStack {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAnimated() }

                focusColumn(width: contentWidth) {
                    optionsStack(placeAbove: placeOptionsAbove)
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: OptionsMeasuredSizeKey.self, value: proxy.size)
                    }
                }
                .onPreferenceChange(OptionsMeasuredSizeKey.self) { optionsSize = $0 }
                .scaleEffect(
                    isRevealed ? 1 : 0.42,
                    anchor: UnitPoint(
                        x: horizontalScaleAnchorX,
                        y: placeOptionsAbove ? 1 : 0
                    )
                )
                .opacity(isRevealed ? 1 : 0)
                .offset(y: isRevealed ? 0 : (placeOptionsAbove ? 14 : -14))
                .position(
                    x: geo.size.width / 2,
                    y: optionsCenterY(
                        placeAbove: placeOptionsAbove,
                        containerHeight: geo.size.height
                    )
                )

                focusColumn(width: contentWidth) {
                    liftedMessage(maxContentWidth: contentWidth)
                }
                .scaleEffect(
                    isRevealed ? messageFocusScale : 0.92,
                    anchor: UnitPoint(x: horizontalScaleAnchorX, y: 0.5)
                )
                .position(
                    x: geo.size.width / 2,
                    y: context.frame.midY
                )
            }
        }
        .animation(MessageReactionTrayMotion.present, value: isRevealed)
        .onAppear {
            isRevealed = false
            withAnimation(MessageReactionTrayMotion.present) {
                isRevealed = true
            }
        }
    }

    /// Shared column so message and options share the same side margins.
    private func focusColumn<Content: View>(
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: width, alignment: contentAlignment)
    }

    @ViewBuilder
    private func optionsStack(placeAbove: Bool) -> some View {
        VStack(alignment: horizontalAlignment, spacing: stackSpacing) {
            if placeAbove {
                replyButton
                reactionTray
            } else {
                reactionTray
                replyButton
            }
        }
        .frame(maxWidth: .infinity, alignment: contentAlignment)
    }

    private var reactionTray: some View {
        MessageReactionTray(
            onReact: onReact,
            onOpenFullPicker: onOpenFullPicker,
            onDismiss: dismissAnimated
        )
    }

    private func liftedMessage(maxContentWidth: CGFloat) -> some View {
        MessageBubble(
            displayMessage: context.displayMessage,
            isOutgoing: context.isOutgoing,
            currentUserId: context.currentUserId,
            isHighlighted: false,
            presentation: .reactionFocusLift,
            focusMaxContentWidth: maxContentWidth,
            onReact: onReact,
            onRetry: nil,
            onLongPress: nil,
            onReply: nil
        )
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: maxContentWidth, alignment: contentAlignment)
        .frame(maxWidth: .infinity, alignment: contentAlignment)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: MessageMeasuredSizeKey.self, value: proxy.size)
            }
        }
        .onPreferenceChange(MessageMeasuredSizeKey.self) { messageSize = $0 }
        .shadow(
            color: .black.opacity(isRevealed ? 0.22 : 0.08),
            radius: isRevealed ? 18 : 6,
            y: isRevealed ? 8 : 2
        )
        .allowsHitTesting(false)
    }

    private var replyButton: some View {
        Button {
            Self.replyImpact.impactOccurred()
            onReply()
            dismissAnimated()
        } label: {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(languageService.text(.messagingReplyAction))
                    .font(SplickTheme.Typography.callout.weight(.semibold))
            }
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private func shouldPlaceOptionsAbove(
        containerHeight: CGFloat,
        optionsHeight: CGFloat
    ) -> Bool {
        let scaledMessageHalf = max(messageSize.height, context.frame.height) * messageFocusScale / 2
        let needed = optionsHeight + stackSpacing
        let spaceAbove = context.frame.midY - scaledMessageHalf - verticalMargin
        let spaceBelow = containerHeight - context.frame.midY - scaledMessageHalf - verticalMargin

        if spaceAbove >= needed, spaceBelow >= needed {
            return spaceAbove >= spaceBelow
        }
        if spaceAbove >= needed { return true }
        if spaceBelow >= needed { return false }
        return spaceAbove >= spaceBelow
    }

    private func optionsCenterY(placeAbove: Bool, containerHeight: CGFloat) -> CGFloat {
        let scaledMessageHalf = max(messageSize.height, context.frame.height) * messageFocusScale / 2
        let optionsHalf = optionsSize.height / 2

        let raw: CGFloat
        if placeAbove {
            raw = context.frame.midY - scaledMessageHalf - stackSpacing - optionsHalf
        } else {
            raw = context.frame.midY + scaledMessageHalf + stackSpacing + optionsHalf
        }

        let minY = verticalMargin + optionsHalf
        let maxY = containerHeight - verticalMargin - optionsHalf
        return min(max(raw, minY), max(maxY, minY))
    }

    private func dismissAnimated() {
        onDismiss()
        withAnimation(MessageReactionTrayMotion.dismiss) {
            isRevealed = false
        }
    }
}

private struct OptionsMeasuredSizeKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 200, height: 88)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1 {
            value = next
        }
    }
}

private struct MessageMeasuredSizeKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 160, height: 44)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1 {
            value = next
        }
    }
}
