import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct FriendRowView: View {
    @EnvironmentObject private var languageService: LanguageService
    let user: UserSummary
    var friendStatus: FriendRelationStatus?
    var isSendingRequest = false
    var onProfileTap: (() -> Void)?
    var onAddFriend: (() -> Void)?

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            profileContent
                .contentShape(Rectangle())
                .onTapGesture {
                    onProfileTap?()
                }

            Spacer(minLength: SplickTheme.Spacing.xs)

            if let friendStatus {
                relationAction(for: friendStatus)
            }
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }

    private var profileContent: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .medium)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(user.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                if let subtitle = user.subtitle {
                    Text(subtitle)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                Text("@\(user.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func relationAction(for status: FriendRelationStatus) -> some View {
        switch status {
        case .friends:
            relationBadge(languageService.text(.friendsRelationFriend), foreground: SplickTheme.Colors.textSecondary)
        case .requestSent:
            relationBadge(languageService.text(.friendsRelationSent), foreground: SplickTheme.Colors.textSecondary)
        case .requestReceived:
            Button {
                onAddFriend?()
            } label: {
                Group {
                    if isSendingRequest {
                        SplickSpinner(size: .small)
                    } else {
                        Text(languageService.text(.friendsAccept))
                            .font(SplickTheme.Typography.caption.weight(.semibold))
                    }
                }
                .frame(minWidth: 72)
                .padding(.horizontal, SplickTheme.Spacing.xs)
                .padding(.vertical, SplickTheme.Spacing.xxxs)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSendingRequest || onAddFriend == nil)
        case .blocked:
            EmptyView()
        case .none:
            Button {
                onAddFriend?()
            } label: {
                Group {
                    if isSendingRequest {
                        SplickSpinner(size: .small)
                    } else {
                        Text(languageService.text(.friendsAddFriendAction))
                            .font(SplickTheme.Typography.caption.weight(.semibold))
                    }
                }
                .frame(minWidth: 72)
                .padding(.horizontal, SplickTheme.Spacing.xs)
                .padding(.vertical, SplickTheme.Spacing.xxxs)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSendingRequest || onAddFriend == nil)
        }
    }

    private func relationBadge(_ title: String, foreground: Color) -> some View {
        Text(title)
            .font(SplickTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, SplickTheme.Spacing.xs)
            .padding(.vertical, SplickTheme.Spacing.xxxs)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(Capsule())
    }
}
