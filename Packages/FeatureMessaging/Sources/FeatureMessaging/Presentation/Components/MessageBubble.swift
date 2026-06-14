import SwiftUI
import DesignSystem
import SplickDomain

struct MessageBubble: View {
    let displayMessage: DisplayMessage
    let isOutgoing: Bool
    let onReact: (String) -> Void

    private static let quickEmojis = ["❤️", "😂", "😮", "😢", "😡", "👏"]

    private var message: ChatMessage { displayMessage.message }

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .font(SplickTheme.Typography.body)
                    .foregroundStyle(isOutgoing ? .white : SplickTheme.Colors.textPrimary)
                    .padding(.horizontal, SplickTheme.Spacing.sm)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                    .background(
                        isOutgoing
                            ? LinearGradient(
                                colors: [SplickTheme.Colors.primaryGradientStart, SplickTheme.Colors.primaryGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [SplickTheme.Colors.secondaryBackground, SplickTheme.Colors.secondaryBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .clipShape(bubbleShape)
                    .contextMenu {
                        ForEach(Self.quickEmojis, id: \.self) { emoji in
                            Button(emoji) { onReact(emoji) }
                        }
                    }

                if !message.reactions.isEmpty {
                    MessageReactionStrip(
                        counts: message.reactionCounts(),
                        isOutgoing: isOutgoing,
                        onReact: onReact
                    )
                }

                if displayMessage.showsTimestamp {
                    Text(message.createdAt.formatted(.dateTime.hour().minute()))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(ChatScrollAnimation.spring, value: displayMessage.showsTimestamp)

            if !isOutgoing { Spacer(minLength: 60) }
        }
        .padding(.top, topSpacing)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let large: CGFloat = 16
        let small: CGFloat = 4

        if isOutgoing {
            // Outgoing: inner edge (leading / left) rounder; outer edge (trailing / right) squarer.
            switch displayMessage.groupPosition {
            case .standalone:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: small,
                    topTrailingRadius: small
                )
            case .groupFirst:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: small,
                    bottomTrailingRadius: small,
                    topTrailingRadius: small
                )
            case .groupMiddle:
                return UnevenRoundedRectangle(
                    topLeadingRadius: large,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: small,
                    topTrailingRadius: small
                )
            case .groupLast:
                return UnevenRoundedRectangle(
                    topLeadingRadius: small,
                    bottomLeadingRadius: large,
                    bottomTrailingRadius: small,
                    topTrailingRadius: small
                )
            }
        } else {
            // Incoming: inner edge (trailing / right) rounder; outer edge (leading / left) squarer.
            switch displayMessage.groupPosition {
            case .standalone:
                return UnevenRoundedRectangle(
                    topLeadingRadius: small,
                    bottomLeadingRadius: small,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupFirst:
                return UnevenRoundedRectangle(
                    topLeadingRadius: small,
                    bottomLeadingRadius: small,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupMiddle:
                return UnevenRoundedRectangle(
                    topLeadingRadius: small,
                    bottomLeadingRadius: small,
                    bottomTrailingRadius: large,
                    topTrailingRadius: large
                )
            case .groupLast:
                return UnevenRoundedRectangle(
                    topLeadingRadius: small,
                    bottomLeadingRadius: small,
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

private struct MessageReactionStrip: View {
    let counts: [(emoji: String, count: Int)]
    let isOutgoing: Bool
    let onReact: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(counts, id: \.emoji) { item in
                Button {
                    onReact(item.emoji)
                } label: {
                    HStack(spacing: 2) {
                        Text(item.emoji)
                        if item.count > 1 {
                            Text("\(item.count)")
                                .font(.caption2)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SplickTheme.Colors.tertiaryBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }
}
