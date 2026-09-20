import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

/// Observes `PresenceStore` in isolation so WebSocket presence updates do not
/// invalidate the entire `PostCardView` body (media, reactions, bill split).
struct PostAuthorPresenceAvatar: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var presenceStore: PresenceStore

    let author: UserSummary
    let onTap: () -> Void

    var body: some View {
        let presence = resolvedPresence
        Button(action: onTap) {
            AvatarWithPresenceView(
                imageURL: author.avatarURL,
                name: author.displayName,
                size: .small,
                userId: author.id,
                showOnlineIndicator: PresenceDisplayPolicy.shouldShowOnlineIndicator(
                    isOnline: presence.isOnline
                ),
                lastSeenLabel: PresenceDisplayPolicy.compactLastSeenLabel(
                    isOnline: presence.isOnline,
                    lastSeenAt: presence.lastSeenAt,
                    appLocale: languageService.locale
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var resolvedPresence: (isOnline: Bool, lastSeenAt: Date?) {
        _ = presenceStore.states
        if let state = presenceStore.state(for: author.id) {
            return (state.isOnline, state.lastSeenAt)
        }
        return (false, nil)
    }
}
