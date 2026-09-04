import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

struct MessageReactionFocusOverlay: View {
    @EnvironmentObject private var languageService: LanguageService

    let context: MessageReactionFocusContext
    /// When false, Reply and the reaction tray are hidden (removed / blocked viewers).
    var allowsThreadInteraction: Bool = true
    var canEdit: Bool = false
    var canRecall: Bool = false
    let onReact: (String) -> Void
    let onReply: () -> Void
    var onEdit: (() -> Void)? = nil
    var onRecall: (() -> Void)? = nil
    let onCopy: () -> Void
    let onDetails: () -> Void
    let onOpenFullPicker: () -> Void
    /// Dim / background tap — may be ignored briefly after long-press opens.
    let onDismiss: () -> Void
    /// Reply / emoji / picker — always tears down focus.
    let onForceDismiss: () -> Void

    @State private var isRevealed = false
    /// Drives the options chrome (reaction tray + action buttons) independently of the dimmer.
    /// Animates in slightly after the bubble pop to create a cascade effect.
    @State private var isOptionsRevealed = false
    @State private var isDismissing = false
    /// Only this drives the bubble motion — never animate position/frame.
    @State private var messagePopScale: CGFloat = 1
    @State private var optionsSize: CGSize = .zero

    private let stackSpacing: CGFloat = 10
    private let horizontalMargin: CGFloat = SplickTheme.Spacing.lg
    private let verticalMargin: CGFloat = SplickTheme.Spacing.md
    private let messageFocusScale: CGFloat = 1.12
    private static let actionImpact = UIImpactFeedbackGenerator(style: .light)

    private var contentAlignment: Alignment {
        context.isOutgoing ? .trailing : .leading
    }

    private var horizontalAlignment: HorizontalAlignment {
        context.isOutgoing ? .trailing : .leading
    }

    private var horizontalScaleAnchorX: CGFloat {
        context.isOutgoing ? 1 : 0
    }

    private var incomingAvatarGutter: CGFloat {
        context.showsSenderAvatar ? MessageThreadRowLayout.senderAvatarGutter : 0
    }

    private var liftedOriginX: CGFloat {
        if context.isOutgoing { return anchorFrame.minX }
        return anchorFrame.minX - incomingAvatarGutter
    }

    private var message: ChatMessage {
        context.displayMessage.message
    }

    private var copyPayload: String? {
        guard !message.recalled else { return nil }
        let trimmed = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Exact list bubble rect — pop/dismiss always use this, never a recalculated slot.
    private var anchorFrame: CGRect {
        context.frame
    }

    /// Tall bubbles keep scale at 1 so ScrollView pans cleanly.
    private var isMessageCapped: Bool {
        anchorFrame.height > 420
    }

    private var estimatedOptionsHeight: CGFloat {
        var chips = 1
        if allowsThreadInteraction && !message.recalled { chips += 1 }
        if canEdit { chips += 1 }
        if copyPayload != nil { chips += 1 }
        if canRecall { chips += 1 }
        let chipHeight: CGFloat = 44
        let chipGap = SplickTheme.Spacing.xs
        let chipsHeight = CGFloat(chips) * chipHeight + CGFloat(max(chips - 1, 0)) * chipGap
        let showTray = allowsThreadInteraction && !message.recalled
        let trayHeight: CGFloat = showTray ? 52 : 0
        let blockGap: CGFloat = showTray ? stackSpacing : 0
        return chipsHeight + trayHeight + blockGap
    }

    var body: some View {
        GeometryReader { geo in
            let resolvedOptionsHeight = optionsSize.height > 1 ? optionsSize.height : estimatedOptionsHeight
            let resolvedOptionsWidth = optionsSize.width > 1 ? optionsSize.width : 180
            let scaleExtra = isMessageCapped ? 0 : anchorFrame.height * (messageFocusScale - 1) / 2
            let placeOptionsAbove = preferredOptionsAbove(
                containerHeight: geo.size.height,
                optionsHeight: resolvedOptionsHeight,
                scaleExtra: scaleExtra
            )
            let optionsTop = optionsTopY(
                placeAbove: placeOptionsAbove,
                optionsHeight: resolvedOptionsHeight,
                scaleExtra: scaleExtra
            )
            let optionsLeading = optionsLeadingX(
                containerWidth: geo.size.width,
                optionsWidth: resolvedOptionsWidth
            )

            ZStack(alignment: .topLeading) {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAnimated() }

                Group {
                    if context.isOutgoing {
                        HStack(alignment: .top, spacing: 0) {
                            Spacer(minLength: 0)
                            liftedMessage(
                                maxContentWidth: MessageThreadRowLayout.contentMaxWidth(
                                    forRowWidth: max(geo.size.width - MessageThreadRowLayout.listHorizontalPadding * 2, 120)
                                ),
                                maxLayoutHeight: min(geo.size.height * 0.55, 420),
                                isCapped: isMessageCapped
                            )
                            .scaleEffect(
                                messagePopScale,
                                anchor: UnitPoint(x: 1, y: 0.5)
                            )
                            .allowsHitTesting(isMessageCapped)
                        }
                        .padding(.top, max(anchorFrame.minY, 0))
                        .padding(.trailing, max(geo.size.width - anchorFrame.maxX, 0))
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    } else {
                        liftedMessage(
                            maxContentWidth: MessageThreadRowLayout.contentMaxWidth(
                                forRowWidth: max(geo.size.width - MessageThreadRowLayout.listHorizontalPadding * 2, 120)
                            ),
                            maxLayoutHeight: min(geo.size.height * 0.55, 420),
                            isCapped: isMessageCapped
                        )
                        .scaleEffect(
                            messagePopScale,
                            anchor: UnitPoint(x: 0, y: 0.5)
                        )
                        .allowsHitTesting(isMessageCapped)
                        .offset(x: liftedOriginX, y: max(anchorFrame.minY, 0))
                    }
                }
                .zIndex(1)

                optionsStack(placeAbove: placeOptionsAbove)
                    .fixedSize()
                    .background(optionsSizeReader)
                    .onPreferenceChange(OptionsMeasuredSizeKey.self) { size in
                        guard size.width > 1, size.height > 1 else { return }
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            optionsSize = size
                        }
                    }
                    .scaleEffect(
                        isOptionsRevealed ? 1 : 0.36,
                        anchor: UnitPoint(
                            x: horizontalScaleAnchorX,
                            y: placeOptionsAbove ? 1 : 0
                        )
                    )
                    .opacity(isOptionsRevealed ? 1 : 0)
                    .offset(y: isOptionsRevealed ? 0 : (placeOptionsAbove ? 14 : -14))
                    .offset(x: optionsLeading, y: optionsTop)
                    .zIndex(2)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .onAppear {
            // Rest scale matches the list bubble; then pop in place (no slide).
            messagePopScale = 1
            isRevealed = false
            isOptionsRevealed = false
            DispatchQueue.main.async {
                // 1. Dim background immediately.
                withAnimation(MessageReactionTrayMotion.present) {
                    isRevealed = true
                }
                // 2. Bubble pops up — fast underdamped spring produces a soft overshoot.
                if !isMessageCapped {
                    withAnimation(MessageReactionTrayMotion.bubblePop) {
                        messagePopScale = messageFocusScale
                    }
                }
                // 3. Options chrome cascades in just after the bubble settles into its first peak.
                DispatchQueue.main.asyncAfter(deadline: .now() + MessageReactionTrayMotion.optionsChromeDelay) {
                    withAnimation(MessageReactionTrayMotion.present) {
                        isOptionsRevealed = true
                    }
                }
            }
        }
        // Isolate focus bounce from list preference / status transaction noise.
        .transaction { transaction in
            if !isDismissing {
                transaction.disablesAnimations = false
            }
        }
    }

    private var optionsSizeReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: OptionsMeasuredSizeKey.self, value: proxy.size)
        }
    }

    @ViewBuilder
    private func optionsStack(placeAbove: Bool) -> some View {
        VStack(alignment: horizontalAlignment, spacing: stackSpacing) {
            if placeAbove {
                actionButtons(placeAbove: true)
                if allowsThreadInteraction && !message.recalled {
                    reactionTray
                }
            } else {
                if allowsThreadInteraction && !message.recalled {
                    reactionTray
                }
                actionButtons(placeAbove: false)
            }
        }
        .frame(alignment: contentAlignment)
    }

    private struct FocusActionItem: Identifiable {
        let id: String
        let titleKey: L10nKey
        let systemImage: String
        let action: () -> Void
    }

    private func orderedActionItems(placeAbove: Bool) -> [FocusActionItem] {
        var items: [FocusActionItem] = []
        if allowsThreadInteraction && !message.recalled {
            items.append(
                FocusActionItem(
                    id: "reply",
                    titleKey: .messagingReplyAction,
                    systemImage: "arrowshape.turn.up.left.fill",
                    action: { dismissCommitted(then: onReply) }
                )
            )
        }
        if canEdit, let onEdit {
            items.append(
                FocusActionItem(
                    id: "edit",
                    titleKey: .messagingEditAction,
                    systemImage: "pencil",
                    action: { dismissCommitted(then: onEdit) }
                )
            )
        }
        if copyPayload != nil {
            items.append(
                FocusActionItem(
                    id: "copy",
                    titleKey: .messagingCopyAction,
                    systemImage: "doc.on.doc",
                    action: {
                        onCopy()
                        dismissCommitted()
                    }
                )
            )
        }
        items.append(
            FocusActionItem(
                id: "details",
                titleKey: .messagingDetailsAction,
                systemImage: "info.circle",
                action: { onDetails() }
            )
        )
        if canRecall, let onRecall {
            items.append(
                FocusActionItem(
                    id: "recall",
                    titleKey: .messagingRecallAction,
                    systemImage: "arrow.uturn.backward",
                    action: { dismissCommitted(then: onRecall) }
                )
            )
        }
        let shortestFirst = items.sorted { lhs, rhs in
            let left = languageService.text(lhs.titleKey)
            let right = languageService.text(rhs.titleKey)
            if left.count != right.count { return left.count < right.count }
            return left < right
        }
        return placeAbove ? shortestFirst : Array(shortestFirst.reversed())
    }

    private func actionButtons(placeAbove: Bool) -> some View {
        let items = orderedActionItems(placeAbove: placeAbove)
        return VStack(alignment: horizontalAlignment, spacing: SplickTheme.Spacing.xs) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let closeness = placeAbove ? index : items.count - 1 - index
                actionButton(
                    titleKey: item.titleKey,
                    systemImage: item.systemImage,
                    minWidth: 108 + CGFloat(closeness) * 16,
                    action: item.action
                )
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
        minWidth: CGFloat = 0,
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
            .frame(minWidth: minWidth, alignment: context.isOutgoing ? .trailing : .leading)
            .background {
                Capsule(style: .continuous)
                    .fill(SplickTheme.Colors.cardBackground)
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
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
        .fixedSize(horizontal: true, vertical: true)

        HStack(alignment: .center, spacing: MessageThreadRowLayout.senderAvatarGap) {
            if context.showsSenderAvatar {
                AvatarView(
                    imageURL: context.senderAvatarURL,
                    name: context.senderAvatarName.isEmpty ? "?" : context.senderAvatarName,
                    size: .small,
                    userId: message.senderId
                )
                .frame(
                    width: MessageThreadRowLayout.senderAvatarSize,
                    height: MessageThreadRowLayout.senderAvatarSize
                )
                .allowsHitTesting(false)
            }

            Group {
                if isCapped {
                    ScrollView(showsIndicators: false) {
                        bubble
                    }
                    .frame(maxWidth: maxContentWidth, maxHeight: maxLayoutHeight, alignment: .top)
                    .fixedSize(horizontal: true, vertical: false)
                    .clipped()
                    .contentShape(Rectangle())
                } else {
                    bubble
                        .frame(maxWidth: maxContentWidth, alignment: contentAlignment)
                }
            }
            .shadow(
                color: .black.opacity(isRevealed ? 0.22 : 0.08),
                radius: isRevealed ? 18 : 6,
                y: isRevealed ? 8 : 2
            )
        }
    }

    private func preferredOptionsAbove(
        containerHeight: CGFloat,
        optionsHeight: CGFloat,
        scaleExtra: CGFloat
    ) -> Bool {
        let needed = optionsHeight + stackSpacing
        let spaceAbove = anchorFrame.minY - scaleExtra - verticalMargin
        let spaceBelow = containerHeight - (anchorFrame.maxY + scaleExtra) - verticalMargin
        let preferAbove = anchorFrame.midY >= containerHeight / 2
        let aboveFits = spaceAbove >= needed
        let belowFits = spaceBelow >= needed
        if preferAbove, aboveFits { return true }
        if !preferAbove, belowFits { return false }
        if aboveFits, !belowFits { return true }
        if belowFits, !aboveFits { return false }
        return spaceAbove >= spaceBelow
    }

    /// Top-leading origin of the options stack — never clamp into the bubble.
    private func optionsTopY(
        placeAbove: Bool,
        optionsHeight: CGFloat,
        scaleExtra: CGFloat
    ) -> CGFloat {
        if placeAbove {
            return anchorFrame.minY - scaleExtra - stackSpacing - optionsHeight
        }
        return anchorFrame.maxY + scaleExtra + stackSpacing
    }

    private func optionsLeadingX(
        containerWidth: CGFloat,
        optionsWidth: CGFloat
    ) -> CGFloat {
        let width = max(optionsWidth, 1)
        let minX = horizontalMargin
        let maxX = max(containerWidth - horizontalMargin - width, minX)
        if context.isOutgoing {
            return min(max(anchorFrame.maxX - width, minX), maxX)
        }
        // Incoming chips follow the bubble leading after the avatar-pinned pop scale.
        return liftedOriginX + incomingAvatarGutter * messagePopScale
    }

    private func dismissAnimated() {
        collapseThenTeardown(force: true)
    }

    private func dismissCommitted(then completion: (() -> Void)? = nil) {
        collapseThenTeardown(force: true, then: completion)
    }

    private func collapseThenTeardown(force: Bool, then completion: (() -> Void)? = nil) {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(MessageReactionTrayMotion.dismiss) {
            isRevealed = false
            isOptionsRevealed = false
            messagePopScale = 1
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
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1 {
            value = next
        }
    }
}
