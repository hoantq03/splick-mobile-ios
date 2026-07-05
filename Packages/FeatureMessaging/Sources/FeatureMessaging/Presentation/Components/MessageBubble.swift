import SwiftUI
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

    private var message: ChatMessage { displayMessage.message }

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.xxs) {
            if isOutgoing {
                timestampRevealArea(alignment: .leading, dragDirection: -1)
                Spacer(minLength: 48)
            }

            bubbleColumn

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

    private var bubbleColumn: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
            ZStack(alignment: isOutgoing ? .bottomTrailing : .bottomLeading) {
                bubbleContent
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: MessageBubbleFrameKey.self,
                                value: [message.id: geo.frame(in: .global)]
                            )
                        }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in onLongPress?() }
                    )

                if let quickEmoji = quickReReactEmoji {
                    quickReReactButton(emoji: quickEmoji)
                        .offset(x: isOutgoing ? 6 : -6, y: 6)
                }
            }

            if !message.reactions.isEmpty {
                MessageReactionStrip(
                    counts: message.reactionCounts(),
                    currentUserId: currentUserId,
                    reactions: message.reactions,
                    isOutgoing: isOutgoing,
                    onReact: onReact
                )
            }
        }
        .messageSendFloat(isActive: isFloatingSend, lateralSway: floatSway)
    }

    private var bubbleContent: some View {
        Text(message.body)
            .font(SplickTheme.Typography.body)
            .foregroundStyle(isOutgoing ? .white : SplickTheme.Colors.textPrimary)
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .padding(.vertical, SplickTheme.Spacing.xs)
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

    private var quickReReactEmoji: String? {
        guard !message.reactions.isEmpty else { return nil }
        return message.lastReactionEmoji(for: currentUserId)
            ?? message.reactionCounts().first?.emoji
    }

    private func quickReReactButton(emoji: String) -> some View {
        Button {
            onReact(emoji)
        } label: {
            EmojiView(value: emoji, size: 22)
                .frame(width: 28, height: 28)
                .background(Circle().fill(SplickTheme.Colors.background))
                .overlay(Circle().stroke(SplickTheme.Colors.divider, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func timestampRevealArea(alignment: HorizontalAlignment, dragDirection: CGFloat) -> some View {
        TimestampRevealSpacer(
            timestamp: message.createdAt,
            dragDirection: dragDirection,
            alignment: alignment
        )
        .frame(minWidth: 52, maxWidth: 72)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let large: CGFloat = 20
        let small: CGFloat = 8

        if isOutgoing {
            switch displayMessage.groupPosition {
            case .standalone:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupFirst:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: small,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupMiddle:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupLast:
                return UnevenRoundedRectangle(
                    topLeadingRadius: small,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            }
        } else {
            switch displayMessage.groupPosition {
            case .standalone:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupFirst:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupMiddle:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupLast:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: large,
                    topTrailingRadius: small
                )
            }
        }
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
    let isOutgoing: Bool
    let onReact: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(counts, id: \.emoji) { item in
                let userReacted = reactions.contains { $0.userId == currentUserId && $0.emoji == item.emoji }

                Button {
                    onReact(item.emoji)
                } label: {
                    HStack(spacing: 2) {
                        EmojiView(value: item.emoji, size: 16)
                        if item.count > 1 {
                            Text("\(item.count)")
                                .font(.caption2)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(
                                userReacted
                                    ? SplickTheme.Colors.primaryGradientStart.opacity(0.12)
                                    : SplickTheme.Colors.tertiaryBackground
                            )
                    )
                    .overlay {
                        if userReacted {
                            Capsule()
                                .stroke(SplickTheme.Colors.primaryGradientStart.opacity(0.35), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }
}
