import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct GroupRowView: View {
    let group: SplickDomain.Group
    @EnvironmentObject private var languageService: LanguageService

    private var subtitle: String {
        let count = languageService.format(.friendsGroupMemberCount, group.memberCount)
        if group.inviteCode.isEmpty {
            return count
        }
        return "\(count) · @\(group.inviteCode)"
    }

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: group.avatarURL, name: group.name, size: .medium)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(group.name)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .splickCard(padding: SplickTheme.Spacing.sm, cornerRadius: SplickTheme.CornerRadius.pill)
    }
}
