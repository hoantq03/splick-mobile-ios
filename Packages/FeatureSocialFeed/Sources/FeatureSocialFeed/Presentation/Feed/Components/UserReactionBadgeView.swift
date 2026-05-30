import SwiftUI
import DesignSystem
import SplickDomain

/// Avatar on the left; emoji samples stacked on the right (1/2 overlap) overlapping the avatar edge.
struct UserReactionBadgeView: View {
    let summary: UserReactionSummary

    private let avatarSize: CGFloat = 28
    private let emojiFontSize: CGFloat = 13

    var body: some View {
        ZStack(alignment: .leading) {
            AvatarView(
                imageURL: summary.user.avatarURL,
                name: summary.user.displayName,
                size: .small
            )
            .frame(width: avatarSize, height: avatarSize)
            .reactionTargetAnchor(id: "user:\(summary.userId.uuidString)")

            if !summary.emojiCounts.isEmpty {
                OverlappingEmojiStack(emojiCounts: summary.emojiCounts, fontSize: emojiFontSize)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(SplickTheme.Colors.background)
                            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                    )
                    .offset(x: avatarSize * 0.5)
            }
        }
        .frame(height: avatarSize)
    }
}

/// Emoji chips stacked with ~1/2 overlap (each step advances half the cell width).
private struct OverlappingEmojiStack: View {
    let emojiCounts: [UserEmojiCount]
    let fontSize: CGFloat

    private var cellWidth: CGFloat { fontSize * 1.2 }
    /// 1/2 overlap → half of each emoji remains visible before the next one.
    private var step: CGFloat { cellWidth / 2 }

    private var stackWidth: CGFloat {
        cellWidth + step * CGFloat(max(emojiCounts.count - 1, 0))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(emojiCounts.enumerated()), id: \.element.emoji) { index, item in
                Text(item.emoji)
                    .font(.system(size: fontSize))
                    .frame(width: cellWidth, height: cellWidth)
                    .background(
                        Circle()
                            .fill(SplickTheme.Colors.background)
                    )
                    .overlay(
                        Circle()
                            .stroke(SplickTheme.Colors.tertiaryBackground, lineWidth: 1)
                    )
                    .zIndex(Double(index))
                    .offset(x: CGFloat(index) * step)
            }
        }
        .frame(width: stackWidth, height: cellWidth, alignment: .leading)
    }
}

/// "+N người bày tỏ cảm xúc khác" chip — fly target when user is outside top 3.
struct MoreReactorsChip: View {
    let count: Int

    var body: some View {
        Text("+\(count) người bày tỏ cảm xúc khác")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 30)
            .background(
                Capsule()
                    .fill(SplickTheme.Colors.tertiaryBackground)
            )
            .reactionTargetAnchor(id: "more")
    }
}
