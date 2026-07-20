import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

struct MessageReactionFocusOverlay: View {
    @EnvironmentObject private var languageService: LanguageService

    let context: MessageReactionFocusContext
    let onReact: (String) -> Void
    let onReply: () -> Void
    let onCopy: () -> Void
    let onDetails: () -> Void
    let onOpenFullPicker: () -> Void
    /// Dim / background tap — may be ignored briefly after long-press opens.
    let onDismiss: () -> Void
    /// Reply / emoji / picker — always tears down focus.
    let onForceDismiss: () -> Void

    @State private var isRevealed = false
    @State private var isDismissing = false
    @State private var optionsSize: CGSize = CGSize(width: 200, height: 88)
    @State private var messageSize: CGSize = CGSize(width: 160, height: 44)
    /// Freeze side + capped choice on first layout so measuring options cannot slide the bubble.
    @State private var frozenPlacement: FrozenPlacement?

    /// Same gap between reply ↔ emoji ↔ message.
    private let stackSpacing: CGFloat = 10
    /// Equal leading/trailing inset — shared by message and options.
    private let horizontalMargin: CGFloat = SplickTheme.Spacing.lg
    private let verticalMargin: CGFloat = SplickTheme.Spacing.md
    /// In-place pop — message stays put and grows toward the viewer.
    private let messageFocusScale: CGFloat = 1.12
    private static let actionImpact = UIImpactFeedbackGenerator(style: .light)
    /// Fallback until the options stack has been measured (tray + 3 action pills).
    private let estimatedOptionsHeight: CGFloat = 200

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

    private var message: ChatMessage {
        context.displayMessage.message
    }

    private var copyPayload: String? {
        let trimmed = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        GeometryReader { geo in
            let columnWidth = max(geo.size.width - horizontalMargin * 2, 120)
            let resolvedOptionsHeight = max(optionsSize.height, estimatedOptionsHeight)
            let placement = frozenPlacement ?? resolvePlacement(
                containerHeight: geo.size.height,
                optionsHeight: resolvedOptionsHeight
            )
            let layout = anchoredLayout(
                placeAbove: placement.placeOptionsAbove,
                containerSize: geo.size,
                optionsHeight: resolvedOptionsHeight
            )
            // Wider only when capped (no pop scale). Short bubbles layout narrower so
            // scaleEffect grows back to the column without horizontal jump.
            let messageLayoutWidth = placement.isMessageCapped
                ? columnWidth
                : floor(columnWidth / messageFocusScale)

            ZStack {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAnimated() }

                // Message — always centered on the long-press frame; only scale pops.
                focusColumn(width: columnWidth) {
                    liftedMessage(
                        maxContentWidth: messageLayoutWidth,
                        maxLayoutHeight: layout.messageHeight,
                        isCapped: placement.isMessageCapped
                    )
                }
                .frame(width: columnWidth, height: layout.messageHeight, alignment: .top)
                .scaleEffect(
                    messageScale,
                    anchor: UnitPoint(x: horizontalScaleAnchorX, y: 0.5)
                )
                .position(x: geo.size.width / 2, y: layout.messageCenterY)
                .allowsHitTesting(placement.isMessageCapped)
                .zIndex(1)

                // Options — float above/below (or screen edge); never drag the bubble.
                focusColumn(width: columnWidth) {
                    optionsStack(placeAbove: placement.placeOptionsAbove)
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(optionsSizeReader)
                .onPreferenceChange(OptionsMeasuredSizeKey.self) { size in
                    guard size.width > 1, size.height > 1, size.height < 500 else { return }
                    optionsSize = size
                }
                .scaleEffect(
                    isRevealed ? 1 : 0.42,
                    anchor: UnitPoint(
                        x: horizontalScaleAnchorX,
                        y: placement.placeOptionsAbove ? 1 : 0
                    )
                )
                .opacity(isRevealed ? 1 : 0)
                .offset(y: isRevealed ? 0 : (placement.placeOptionsAbove ? 14 : -14))
                .position(x: geo.size.width / 2, y: layout.optionsCenterY)
                .zIndex(2)
            }
            .onAppear {
                if frozenPlacement == nil {
                    frozenPlacement = resolvePlacement(
                        containerHeight: geo.size.height,
                        optionsHeight: resolvedOptionsHeight
                    )
                }
            }
        }
        .onAppear {
            // Defer so the first frame paints at rest scale; same-runloop false→true can no-op.
            isRevealed = false
            DispatchQueue.main.async {
                withAnimation(MessageReactionTrayMotion.present) {
                    isRevealed = true
                }
            }
        }
    }

    /// Match the list bubble at rest (1), then pop in place. Never start smaller —
    /// that reads as a slide when combined with layout changes.
    private var messageScale: CGFloat {
        if isMessageCappedCurrent {
            return 1
        }
        return isRevealed ? messageFocusScale : 1
    }

    private var isMessageCappedCurrent: Bool {
        frozenPlacement?.isMessageCapped ?? false
    }

    private var optionsSizeReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: OptionsMeasuredSizeKey.self, value: proxy.size)
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
                actionButtons
                reactionTray
            } else {
                reactionTray
                actionButtons
            }
        }
        .frame(maxWidth: .infinity, alignment: contentAlignment)
    }

    private var actionButtons: some View {
        VStack(alignment: horizontalAlignment, spacing: SplickTheme.Spacing.xs) {
            actionButton(
                titleKey: .messagingReplyAction,
                systemImage: "arrowshape.turn.up.left.fill"
            ) {
                dismissCommitted(then: onReply)
            }
            if copyPayload != nil {
                actionButton(
                    titleKey: .messagingCopyAction,
                    systemImage: "doc.on.doc"
                ) {
                    onCopy()
                    dismissCommitted()
                }
            }
            actionButton(
                titleKey: .messagingDetailsAction,
                systemImage: "info.circle"
            ) {
                dismissCommitted(then: onDetails)
            }
        }
    }

    private var reactionTray: some View {
        MessageReactionTray(
            onReact: onReact,
            onOpenFullPicker: {
                dismissCommitted(then: onOpenFullPicker)
            },
            onDismiss: { dismissCommitted() }
        )
    }

    private func actionButton(
        titleKey: L10nKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Self.actionImpact.impactOccurred()
            action()
        } label: {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(languageService.text(titleKey))
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

    @ViewBuilder
    private func liftedMessage(
        maxContentWidth: CGFloat,
        maxLayoutHeight: CGFloat,
        isCapped: Bool
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
        .onPreferenceChange(MessageMeasuredSizeKey.self) { size in
            guard size.width > 1, size.height > 1, size.height < 2_000 else { return }
            messageSize = size
        }

        Group {
            if isCapped {
                ScrollView(showsIndicators: false) {
                    bubble
                        .frame(maxWidth: maxContentWidth, alignment: contentAlignment)
                }
                .frame(maxWidth: .infinity, maxHeight: maxLayoutHeight, alignment: .top)
                .clipped()
                .contentShape(Rectangle())
            } else {
                bubble
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxLayoutHeight, alignment: .top)
        .shadow(
            color: .black.opacity(isRevealed ? 0.22 : 0.08),
            radius: isRevealed ? 18 : 6,
            y: isRevealed ? 8 : 2
        )
    }

    private struct FrozenPlacement {
        let placeOptionsAbove: Bool
        let isMessageCapped: Bool
    }

    private struct AnchoredLayout {
        let messageCenterY: CGFloat
        let messageHeight: CGFloat
        let optionsCenterY: CGFloat
    }

    /// Decide options side once. Message never leaves `context.frame`.
    private func resolvePlacement(
        containerHeight: CGFloat,
        optionsHeight: CGFloat
    ) -> FrozenPlacement {
        let needed = optionsHeight + stackSpacing
        let spaceAbove = context.frame.minY - verticalMargin
        let spaceBelow = containerHeight - context.frame.maxY - verticalMargin
        let canFitAbove = spaceAbove >= needed
        let canFitBelow = spaceBelow >= needed

        let maxViewport = max(
            containerHeight - verticalMargin * 2,
            120
        )
        let intrinsicHeight = max(messageSize.height, context.frame.height, 1)
        let isMessageCapped = intrinsicHeight > maxViewport + 1
            || (!canFitAbove && !canFitBelow && intrinsicHeight > containerHeight * 0.45)

        let placeOptionsAbove: Bool
        if canFitAbove, canFitBelow {
            placeOptionsAbove = spaceAbove >= spaceBelow
        } else if canFitAbove {
            placeOptionsAbove = true
        } else if canFitBelow {
            placeOptionsAbove = false
        } else {
            // Neither side fits beside the bubble — park options on the roomier screen edge.
            placeOptionsAbove = spaceAbove >= spaceBelow
        }

        return FrozenPlacement(
            placeOptionsAbove: placeOptionsAbove,
            isMessageCapped: isMessageCapped
        )
    }

    /// Message center tracks the long-press frame; options float around it (or to a screen edge).
    private func anchoredLayout(
        placeAbove: Bool,
        containerSize: CGSize,
        optionsHeight: CGFloat
    ) -> AnchoredLayout {
        let minY = verticalMargin
        let maxY = containerSize.height - verticalMargin
        let maxViewport = max(maxY - minY, 120)

        // Anchor to the on-screen portion of the long-press frame so the bubble never
        // slides to make room for options — present/dismiss are pure scale at this spot.
        let safeBounds = CGRect(
            x: 0,
            y: minY,
            width: containerSize.width,
            height: maxY - minY
        )
        let visible = context.frame.intersection(safeBounds)
        let messageHeight: CGFloat
        let messageCenterY: CGFloat
        if visible.height > 1 {
            messageHeight = min(visible.height, maxViewport)
            messageCenterY = visible.midY
        } else {
            messageHeight = min(max(context.frame.height, 1), maxViewport)
            messageCenterY = min(
                max(context.frame.midY, minY + messageHeight / 2),
                maxY - messageHeight / 2
            )
        }

        let messageTop = messageCenterY - messageHeight / 2
        let messageBottom = messageCenterY + messageHeight / 2
        let optionsHalf = optionsHeight / 2

        let optionsCenterY: CGFloat
        if placeAbove {
            let idealBottom = messageTop - stackSpacing
            let idealCenter = idealBottom - optionsHalf
            if idealCenter - optionsHalf >= minY {
                optionsCenterY = idealCenter
            } else {
                // Screen-top band — do not move the message to make room.
                optionsCenterY = minY + optionsHalf
            }
        } else {
            let idealTop = messageBottom + stackSpacing
            let idealCenter = idealTop + optionsHalf
            if idealCenter + optionsHalf <= maxY {
                optionsCenterY = idealCenter
            } else {
                optionsCenterY = maxY - optionsHalf
            }
        }

        return AnchoredLayout(
            messageCenterY: messageCenterY,
            messageHeight: messageHeight,
            optionsCenterY: optionsCenterY
        )
    }

    private func dismissAnimated() {
        // Dim tap is intentional — always tear down after the collapse spring.
        collapseThenTeardown(force: true)
    }

    private func dismissCommitted(then completion: (() -> Void)? = nil) {
        collapseThenTeardown(force: true, then: completion)
    }

    /// Mirror the present spring in reverse, then tear down so the list bubble can return.
    private func collapseThenTeardown(force: Bool, then completion: (() -> Void)? = nil) {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(MessageReactionTrayMotion.dismiss) {
            isRevealed = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + MessageReactionTrayMotion.dismissSettlingDelay) {
            if force {
                onForceDismiss()
            } else {
                onDismiss()
            }
            completion?()
        }
    }
}

private struct OptionsMeasuredSizeKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 200, height: 88)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1, next.height < 500 {
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
