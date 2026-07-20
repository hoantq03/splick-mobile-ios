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
    /// Only this drives the bubble motion — never animate position/frame.
    @State private var messagePopScale: CGFloat = 1
    @State private var optionsSize: CGSize = CGSize(width: 200, height: 88)
    /// Freeze options side on first layout so measuring cannot reshuffle chrome.
    @State private var placeOptionsAbove = true
    @State private var didFreezePlacement = false

    private let stackSpacing: CGFloat = 10
    private let horizontalMargin: CGFloat = SplickTheme.Spacing.lg
    private let verticalMargin: CGFloat = SplickTheme.Spacing.md
    private let messageFocusScale: CGFloat = 1.12
    private static let actionImpact = UIImpactFeedbackGenerator(style: .light)
    private let estimatedOptionsHeight: CGFloat = 200

    private var contentAlignment: Alignment {
        context.isOutgoing ? .trailing : .leading
    }

    private var horizontalAlignment: HorizontalAlignment {
        context.isOutgoing ? .trailing : .leading
    }

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

    /// Exact list bubble rect — pop/dismiss always use this, never a recalculated slot.
    private var anchorFrame: CGRect {
        context.frame
    }

    /// Tall bubbles keep scale at 1 so ScrollView pans cleanly.
    private var isMessageCapped: Bool {
        anchorFrame.height > 420
    }

    var body: some View {
        GeometryReader { geo in
            let columnWidth = max(geo.size.width - horizontalMargin * 2, 120)
            let resolvedOptionsHeight = max(optionsSize.height, estimatedOptionsHeight)
            let optionsCenterY = optionsCenterY(
                placeAbove: placeOptionsAbove,
                containerHeight: geo.size.height,
                optionsHeight: resolvedOptionsHeight
            )

            ZStack {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAnimated() }

                // Bubble stays glued to the long-press frame; only `messagePopScale` animates.
                liftedMessage(
                    maxContentWidth: max(anchorFrame.width, 1),
                    maxLayoutHeight: max(anchorFrame.height, 1),
                    isCapped: isMessageCapped
                )
                .frame(width: anchorFrame.width, height: anchorFrame.height, alignment: .top)
                .scaleEffect(
                    messagePopScale,
                    anchor: UnitPoint(x: horizontalScaleAnchorX, y: 0.5)
                )
                .position(x: anchorFrame.midX, y: anchorFrame.midY)
                .allowsHitTesting(isMessageCapped)
                .zIndex(1)

                focusColumn(width: columnWidth) {
                    optionsStack(placeAbove: placeOptionsAbove)
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(optionsSizeReader)
                .onPreferenceChange(OptionsMeasuredSizeKey.self) { size in
                    guard size.width > 1, size.height > 1, size.height < 500 else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        optionsSize = size
                    }
                }
                .scaleEffect(
                    isRevealed ? 1 : 0.42,
                    anchor: UnitPoint(
                        x: horizontalScaleAnchorX,
                        y: placeOptionsAbove ? 1 : 0
                    )
                )
                .opacity(isRevealed ? 1 : 0)
                .offset(y: isRevealed ? 0 : (placeOptionsAbove ? 10 : -10))
                .position(x: geo.size.width / 2, y: optionsCenterY)
                .zIndex(2)
            }
            .onAppear {
                guard !didFreezePlacement else { return }
                didFreezePlacement = true
                placeOptionsAbove = preferredOptionsAbove(
                    containerHeight: geo.size.height,
                    optionsHeight: resolvedOptionsHeight
                )
            }
        }
        .onAppear {
            // Rest scale matches the list bubble; then pop in place (no slide).
            messagePopScale = 1
            isRevealed = false
            DispatchQueue.main.async {
                withAnimation(MessageReactionTrayMotion.present) {
                    isRevealed = true
                    if !isMessageCapped {
                        messagePopScale = messageFocusScale
                    }
                }
            }
        }
    }

    private var optionsSizeReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: OptionsMeasuredSizeKey.self, value: proxy.size)
        }
    }

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

    private func preferredOptionsAbove(
        containerHeight: CGFloat,
        optionsHeight: CGFloat
    ) -> Bool {
        let needed = optionsHeight + stackSpacing
        let spaceAbove = anchorFrame.minY - verticalMargin
        let spaceBelow = containerHeight - anchorFrame.maxY - verticalMargin
        if spaceAbove >= needed, spaceBelow >= needed {
            return spaceAbove >= spaceBelow
        }
        if spaceAbove >= needed { return true }
        if spaceBelow >= needed { return false }
        return spaceAbove >= spaceBelow
    }

    /// Options float around the anchored bubble (or to a screen edge) — bubble never moves.
    private func optionsCenterY(
        placeAbove: Bool,
        containerHeight: CGFloat,
        optionsHeight: CGFloat
    ) -> CGFloat {
        let minY = verticalMargin
        let maxY = containerHeight - verticalMargin
        let optionsHalf = optionsHeight / 2

        if placeAbove {
            let ideal = anchorFrame.minY - stackSpacing - optionsHalf
            if ideal - optionsHalf >= minY {
                return ideal
            }
            return minY + optionsHalf
        } else {
            let ideal = anchorFrame.maxY + stackSpacing + optionsHalf
            if ideal + optionsHalf <= maxY {
                return ideal
            }
            return maxY - optionsHalf
        }
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
    static var defaultValue: CGSize = CGSize(width: 200, height: 88)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1, next.height < 500 {
            value = next
        }
    }
}
