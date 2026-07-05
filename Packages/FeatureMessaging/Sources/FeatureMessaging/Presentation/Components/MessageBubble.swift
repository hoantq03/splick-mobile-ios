import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain

struct MessageBubble: View {
    @EnvironmentObject private var languageService: LanguageService

    let displayMessage: DisplayMessage
    let isOutgoing: Bool
    let currentUserId: UUID
    var isHighlighted: Bool = false
    var isFloatingSend: Bool = false
    var floatSway: CGFloat = 0
    let onReact: (String) -> Void
    let onRetry: (() -> Void)?
    let onLongPress: (() -> Void)?

    private static let longPressImpact = UIImpactFeedbackGenerator(style: .medium)

    private var message: ChatMessage { displayMessage.message }

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.xxs) {
            if isOutgoing {
                timestampRevealArea(alignment: .leading, dragDirection: -1)
                Spacer(minLength: 48)
            }

            bubbleCluster

            if isOutgoing {
                if message.deliveryStatus != .failed {
                    MessageStatusIndicator(status: message.deliveryStatus)
                        .padding(.bottom, 2)
                }
            }

            if !isOutgoing {
                Spacer(minLength: 48)
                timestampRevealArea(alignment: .trailing, dragDirection: 1)
            }
        }
        .padding(.top, topSpacing)
    }

    private static let reactionAccessoryHeight: CGFloat = 26
    /// Half the accessory sits below the bubble bottom edge, half overlaps the bubble.
    private static let reactionAccessoryOverlap: CGFloat = reactionAccessoryHeight / 2

    private var bubbleCluster: some View {
        bubbleContent
            .simultaneousGesture(longPressGesture)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: MessageReactionAnchorFrameKey.self,
                        value: [message.id: geo.frame(in: .global)]
                    )
                }
            }
            .overlay(alignment: isOutgoing ? .bottomLeading : .bottomTrailing) {
                if showsReactionAccessory {
                    MessageReactionStrip(
                        counts: message.reactionCountsInsideOut(isOutgoing: isOutgoing),
                        currentUserId: currentUserId,
                        reactions: message.reactions,
                        onReact: onReact
                    )
                    .offset(y: Self.reactionAccessoryOverlap)
                }
            }
            .padding(.bottom, showsReactionAccessory ? Self.reactionAccessoryOverlap : 0)
            .messageSendFloat(isActive: isFloatingSend, lateralSway: floatSway)
    }

    private var showsReactionAccessory: Bool {
        !message.reactions.isEmpty
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .onEnded { _ in
                guard onLongPress != nil else { return }
                Self.longPressImpact.impactOccurred()
                onLongPress?()
            }
    }

    private var bubbleContent: some View {
        Text(message.body)
            .font(SplickTheme.Typography.body)
            .foregroundStyle(isOutgoing ? .white : SplickTheme.Colors.textPrimary)
            .padding(.horizontal, SplickTheme.Spacing.sm + 2)
            .padding(.vertical, SplickTheme.Spacing.xs + 2)
            .background(bubbleBackground)
            .clipShape(bubbleShape)
            .overlay {
                if isHighlighted {
                    bubbleShape
                        .stroke(SplickTheme.Colors.primaryGradientStart.opacity(0.85), lineWidth: 2)
                        .background(
                            bubbleShape.fill(SplickTheme.Colors.primaryGradientStart.opacity(0.15))
                        )
                }
            }
            .overlay {
                if message.deliveryStatus == .failed {
                    failedOverlay
                }
            }
            .contentShape(bubbleShape)
            .onTapGesture {
                if message.deliveryStatus == .failed {
                    onRetry?()
                }
            }
    }

    private var failedOverlay: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.15)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 120
            )
            .clipShape(bubbleShape)

            Text(languageService.text(.messagingTapToRetry))
                .font(SplickTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.xs)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isOutgoing {
            LinearGradient(
                colors: [SplickTheme.Colors.primaryGradientStart, SplickTheme.Colors.primaryGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(message.deliveryStatus == .failed ? 0.45 : 1)
        } else {
            LinearGradient(
                colors: [SplickTheme.Colors.secondaryBackground, SplickTheme.Colors.secondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func timestampRevealArea(alignment: HorizontalAlignment, dragDirection: CGFloat) -> some View {
        TimestampRevealSpacer(
            timestamp: message.createdAt,
            dragDirection: dragDirection,
            alignment: alignment
        )
        .frame(minWidth: 52, maxWidth: 72)
    }

    private static let bubbleCornerRadius: CGFloat = 24

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.bubbleCornerRadius, style: .continuous)
    }

    private var topSpacing: CGFloat {
        switch displayMessage.groupPosition {
        case .standalone, .groupFirst:
            return SplickTheme.Spacing.sm
        case .groupMiddle, .groupLast:
            return 2
        }
    }
}

private struct TimestampRevealSpacer: View {
    let timestamp: Date
    let dragDirection: CGFloat
    let alignment: HorizontalAlignment

    @GestureState private var dragOffset: CGFloat = 0

    private var revealProgress: CGFloat {
        min(abs(dragOffset) / 60, 1)
    }

    var body: some View {
        ZStack(alignment: alignment == .leading ? .leading : .trailing) {
            Text(timestamp.formatted(.dateTime.hour().minute()))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .opacity(revealProgress)
                .offset(x: dragDirection > 0 ? (24 - dragOffset) : (-24 - dragOffset))
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .updating($dragOffset) { value, state, _ in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard abs(horizontal) > vertical else { return }
                    if dragDirection < 0 {
                        state = min(0, horizontal)
                    } else {
                        state = max(0, horizontal)
                    }
                }
        )
    }
}

private struct MessageReactionStrip: View {
    let counts: [(emoji: String, count: Int)]
    let currentUserId: UUID
    let reactions: [Reaction]
    let onReact: (String) -> Void

    @State private var bouncingEmoji: String?

    private static let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        HStack(spacing: 4) {
            ForEach(counts, id: \.emoji) { item in
                let userReacted = reactions.contains { $0.userId == currentUserId && $0.emoji == item.emoji }
                let isBouncing = bouncingEmoji == item.emoji

                Button {
                    commitReaction(emoji: item.emoji)
                } label: {
                    HStack(spacing: 2) {
                        EmojiView(value: item.emoji, size: 18)
                        if item.count > 1 {
                            Text("\(item.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background {
                        Capsule(style: .continuous)
                            .fill(SplickTheme.Colors.background)
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                userReacted
                                    ? SplickTheme.Colors.primaryGradientStart.opacity(0.55)
                                    : SplickTheme.Colors.divider,
                                lineWidth: 0.5
                            )
                    }
                    .reactionTapBounce(isActive: isBouncing)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { Self.impactFeedback.prepare() }
    }

    private func commitReaction(emoji: String) {
        Self.impactFeedback.impactOccurred()
        Self.impactFeedback.prepare()
        bouncingEmoji = emoji
        DispatchQueue.main.asyncAfter(deadline: .now() + ReactionTapBounce.settleDelay) {
            if bouncingEmoji == emoji { bouncingEmoji = nil }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ReactionTapBounce.commitDelay) {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                onReact(emoji)
            }
        }
    }
}
