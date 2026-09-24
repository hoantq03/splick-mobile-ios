import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

struct InboxActiveFriendsStrip: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var presenceStore: PresenceStore

    let friends: [UserSummary]
    let isStartingConversation: Bool
    let onCompose: () -> Void
    let onSelect: (UserSummary) -> Void

    private static let avatarSize: CGFloat = 64
    private static let inboxAvatarSize: CGFloat = 48
    private static let labelWidth: CGFloat = 78
    private static let dividerHeight: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
            composeButton

            if !orderedFriends.isEmpty {
                Capsule()
                    .fill(SplickTheme.Colors.textTertiary.opacity(0.45))
                    .frame(width: 1.5, height: Self.dividerHeight)
                    .padding(.top, (Self.avatarSize - Self.dividerHeight) / 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: SplickTheme.Spacing.md) {
                    ForEach(orderedFriends) { friend in
                        friendButton(friend)
                    }
                }
                .padding(.trailing, SplickTheme.Spacing.md)
            }
        }
        .padding(.leading, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.xs)
    }

    private var orderedFriends: [UserSummary] {
        InboxFriendOrdering.sorted(friends, presence: presenceStore.states)
    }

    private var composeButton: some View {
        Button(action: onCompose) {
            VStack(spacing: SplickTheme.Spacing.xxxs) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: Self.avatarSize, height: Self.avatarSize)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(Circle())

                Text(languageService.text(.messagingNewConversation))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: Self.labelWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.messagingNewConversation))
    }

    private func friendButton(_ friend: UserSummary) -> some View {
        let presence = resolvedPresence(for: friend.id)
        return Button {
            onSelect(friend)
        } label: {
            VStack(spacing: SplickTheme.Spacing.xxxs) {
                ConversationListAvatar(
                    imageURL: friend.avatarURL,
                    name: friend.preferredName,
                    userId: friend.id,
                    isOnline: PresenceDisplayPolicy.shouldShowOnlineIndicator(isOnline: presence.isOnline),
                    lastSeenLabel: PresenceDisplayPolicy.compactLastSeenLabel(
                        isOnline: presence.isOnline,
                        lastSeenAt: presence.lastSeenAt,
                        appLocale: languageService.locale
                    )
                )
                .scaleEffect(Self.avatarSize / Self.inboxAvatarSize)
                .frame(width: Self.avatarSize, height: Self.avatarSize)

                Text(shortName(friend.preferredName))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(width: Self.labelWidth)
            }
        }
        .buttonStyle(.plain)
        .disabled(isStartingConversation)
        .accessibilityLabel(friend.preferredName)
    }

    private func resolvedPresence(for userId: UUID) -> (isOnline: Bool, lastSeenAt: Date?) {
        guard let state = presenceStore.state(for: userId) else {
            return (false, nil)
        }
        return (state.isOnline, state.lastSeenAt)
    }

    private func shortName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(separator: " ").first else { return trimmed }
        return String(first)
    }
}
