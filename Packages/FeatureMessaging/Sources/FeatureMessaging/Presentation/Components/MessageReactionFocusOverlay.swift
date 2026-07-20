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
    /// Fallback until the options stack has been measured.
    private let estimatedOptionsHeight: CGFloat = 96

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
            let columnWidth = max(geo.size.width - horizontalMargin * 2, 120)
            // Layout narrower so after scale the bubble still fits inside equal side margins.
            let messageLayoutWidth = floor(columnWidth / messageFocusScale)
            let resolvedOptionsHeight = max(optionsSize.height, estimatedOptionsHeight)
            let placeOptionsAbove = shouldPlaceOptionsAbove(
                containerHeight: geo.size.height,
                optionsHeight: resolvedOptionsHeight
            )
            // Always leave room for options + gap + safe margins.
            let maxMessageVisualHeight = max(
                geo.size.height - resolvedOptionsHeight - stackSpacing - verticalMargin * 2,
                120
            )
            let maxMessageLayoutHeight = floor(maxMessageVisualHeight / messageFocusScale)
            let layout = verticalLayout(
                placeAbove: placeOptionsAbove,
                containerHeight: geo.size.height,
                optionsHeight: resolvedOptionsHeight,
                messageLayoutHeight: min(max(messageSize.height, 1), maxMessageLayoutHeight)
            )

            ZStack {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAnimated() }

                // Message under options so a tall bubble never covers emoji/reply.
                focusColumn(width: columnWidth) {
                    liftedMessage(
                        maxContentWidth: messageLayoutWidth,
                        maxLayoutHeight: maxMessageLayoutHeight,
                        pinToBottom: placeOptionsAbove
                    )
                }
                .scaleEffect(
                    isRevealed ? messageFocusScale : 0.92,
                    anchor: UnitPoint(
                        x: horizontalScaleAnchorX,
                        y: placeOptionsAbove ? 1 : 0
                    )
                )
                .position(x: geo.size.width / 2, y: layout.messageCenterY)

                focusColumn(width: columnWidth) {
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
                .position(x: geo.size.width / 2, y: layout.optionsCenterY)
            }
        }
        .onAppear {
            // Defer so the first frame paints collapsed; same-runloop false→true can no-op.
            isRevealed = false
            DispatchQueue.main.async {
                withAnimation(MessageReactionTrayMotion.present) {
                    isRevealed = true
                }
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

    private func liftedMessage(
        maxContentWidth: CGFloat,
        maxLayoutHeight: CGFloat,
        pinToBottom: Bool
    ) -> some View {
        let bubble = MessageBubble(
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
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: MessageMeasuredSizeKey.self, value: proxy.size)
            }
        }
        .onPreferenceChange(MessageMeasuredSizeKey.self) { messageSize = $0 }

        return ScrollView(showsIndicators: false) {
            bubble
        }
        .frame(maxHeight: maxLayoutHeight, alignment: pinToBottom ? .bottom : .top)
        .frame(maxWidth: .infinity, alignment: contentAlignment)
        .shadow(
            color: .black.opacity(isRevealed ? 0.22 : 0.08),
            radius: isRevealed ? 18 : 6,
            y: isRevealed ? 8 : 2
        )
        // Only intercept scrolls when content actually overflows.
        .allowsHitTesting(messageSize.height > maxLayoutHeight + 1)
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

    private struct VerticalLayout {
        let messageCenterY: CGFloat
        let optionsCenterY: CGFloat
    }

    private func shouldPlaceOptionsAbove(
        containerHeight: CGFloat,
        optionsHeight: CGFloat
    ) -> Bool {
        let needed = optionsHeight + stackSpacing
        let spaceAbove = context.frame.minY - verticalMargin
        let spaceBelow = containerHeight - context.frame.maxY - verticalMargin

        if spaceAbove >= needed, spaceBelow >= needed {
            return spaceAbove >= spaceBelow
        }
        if spaceAbove >= needed { return true }
        if spaceBelow >= needed { return false }
        return spaceAbove >= spaceBelow
    }

    /// Options stay visible; short messages keep near the original bubble, long ones fill the rest.
    private func verticalLayout(
        placeAbove: Bool,
        containerHeight: CGFloat,
        optionsHeight: CGFloat,
        messageLayoutHeight: CGFloat
    ) -> VerticalLayout {
        let visualMessageHeight = messageLayoutHeight * messageFocusScale
        let minY = verticalMargin
        let maxY = containerHeight - verticalMargin

        if placeAbove {
            var messageBottom = min(context.frame.maxY, maxY)
            var messageTop = messageBottom - visualMessageHeight
            var optionsBottom = messageTop - stackSpacing
            var optionsTop = optionsBottom - optionsHeight

            if optionsTop < minY {
                optionsTop = minY
                optionsBottom = optionsTop + optionsHeight
                messageTop = optionsBottom + stackSpacing
                messageBottom = min(messageTop + visualMessageHeight, maxY)
            }

            return VerticalLayout(
                messageCenterY: (messageTop + messageBottom) / 2,
                optionsCenterY: (optionsTop + optionsBottom) / 2
            )
        } else {
            var messageTop = max(context.frame.minY, minY)
            var messageBottom = messageTop + visualMessageHeight
            var optionsTop = messageBottom + stackSpacing
            var optionsBottom = optionsTop + optionsHeight

            if optionsBottom > maxY {
                optionsBottom = maxY
                optionsTop = optionsBottom - optionsHeight
                messageBottom = optionsTop - stackSpacing
                messageTop = max(messageBottom - visualMessageHeight, minY)
            }

            return VerticalLayout(
                messageCenterY: (messageTop + messageBottom) / 2,
                optionsCenterY: (optionsTop + optionsBottom) / 2
            )
        }
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
