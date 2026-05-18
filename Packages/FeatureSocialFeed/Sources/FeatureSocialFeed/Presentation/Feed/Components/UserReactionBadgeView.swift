import SwiftUI
import DesignSystem
import SplickDomain

/// Avatar on the left; emoji samples on the right overlapping ~half the avatar (no counts on feed).
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
                HStack(spacing: 1) {
                    ForEach(summary.emojiCounts, id: \.emoji) { item in
                        Text(item.emoji)
                            .font(.system(size: emojiFontSize))
                    }
                }
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
