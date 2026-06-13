import SwiftUI
import DesignSystem
import SplickDomain

/// Friend suggestion row for tag/mention pickers — only avatar + name area is tappable.
struct FriendTagRow: View {
    let friend: UserSummary
    let onTap: () -> Void

    var avatarSize: AvatarView.Size = .small
    var horizontalPadding: CGFloat = SplickTheme.Spacing.sm
    var verticalPadding: CGFloat = SplickTheme.Spacing.xs

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Button(action: onTap) {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    AvatarView(
                        imageURL: friend.avatarURL,
                        name: friend.displayName,
                        size: avatarSize
                    )
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.displayName)
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                        Text("@\(friend.username)")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
    }
}
