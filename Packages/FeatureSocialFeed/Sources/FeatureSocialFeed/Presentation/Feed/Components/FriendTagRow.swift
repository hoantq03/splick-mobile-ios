import SwiftUI
import DesignSystem
import SplickDomain

/// Friend suggestion row for tag/mention pickers.
struct FriendTagRow: View {
    let friend: UserSummary
    let onTap: () -> Void

    var avatarSize: AvatarView.Size = .small
    var horizontalPadding: CGFloat = SplickTheme.Spacing.sm
    var verticalPadding: CGFloat = SplickTheme.Spacing.xs

    var body: some View {
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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .onTapGesture(perform: onTap)
    }
}
