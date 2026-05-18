import SwiftUI
import DesignSystem
import SplickDomain

struct FriendRowView: View {
    let user: UserSummary

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .medium)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(user.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text("@\(user.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
