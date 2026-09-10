import SwiftUI
import DesignSystem
import SplickDomain

struct TappableUserRow: View {
    let user: UserSummary
    var subtitle: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                AvatarView(
                    imageURL: user.avatarURL,
                    name: user.displayName,
                    size: .small
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    } else {
                        Text("@\(user.username)")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
