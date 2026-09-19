import SwiftUI
import DesignSystem
import Localization

struct GroupMemberRowView: View {
    @EnvironmentObject private var languageService: LanguageService
    let displayName: String
    let username: String
    let avatarURL: URL?
    var onProfileTap: (() -> Void)?
    var onRemove: (() -> Void)?

    private let rowCornerRadius = SplickTheme.CornerRadius.pill
    private let actionIconSize: CGFloat = 36

    var body: some View {
        Group {
            if let onProfileTap, onRemove == nil {
                rowContent
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onProfileTap)
            } else {
                rowContent
            }
        }
        .splickCard(padding: SplickTheme.Spacing.sm, cornerRadius: rowCornerRadius)
    }

    private var rowContent: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            profileSection
            Spacer(minLength: SplickTheme.Spacing.xs)
            if let onRemove {
                memberActionMenu(onRemove: onRemove)
            }
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        if let onProfileTap, onRemove != nil {
            profileContent
                .contentShape(Rectangle())
                .onTapGesture(perform: onProfileTap)
        } else {
            profileContent
        }
    }

    private var profileContent: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: avatarURL, name: displayName, size: .medium)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text("@\(username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    private func memberActionMenu(onRemove: @escaping () -> Void) -> some View {
        Menu {
            Button(role: .destructive, action: onRemove) {
                Label(languageService.text(.friendsGroupRemoveMemberAction), systemImage: "person.fill.xmark")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: actionIconSize, height: actionIconSize)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(Circle())
        }
        .accessibilityLabel(languageService.text(.friendsGroupMemberActionsA11y))
    }
}
