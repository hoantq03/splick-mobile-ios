import SwiftUI
import Common
import DesignSystem
import SplickDomain

struct MessagingSearchResultRowView: View {
    let result: MessagingSearchResult
    let query: String
    let isStarting: Bool

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(
                imageURL: avatarURL,
                name: titleText,
                size: .medium
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    titleView
                        .lineLimit(1)
                    Spacer()
                    if let timestamp = trailingTimestamp {
                        Text(timestamp)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                }

                subtitleView
                    .lineLimit(1)
            }

            if isStarting {
                SplickSpinner().controlSize(.small)
            }
        }
        .padding(.vertical, SplickTheme.Spacing.xs)
    }

    private var avatarURL: URL? {
        switch result {
        case .user(let user):
            return user.avatarURL
        case .message(let hit):
            return hit.peer.avatarUrl.flatMap(URL.init(string:))
        case .conversation(let conversation):
            return conversation.groupAvatarUrl.flatMap(URL.init(string:))
                ?? conversation.peer?.avatarUrl.flatMap(URL.init(string:))
        }
    }

    private var titleText: String {
        switch result {
        case .user(let user):
            return user.displayName
        case .message(let hit):
            return hit.peer.displayTitle
        case .conversation(let conversation):
            return conversation.displayTitle
        }
    }

    @ViewBuilder
    private var titleView: some View {
        switch result {
        case .user(let user):
            HighlightedText(
                user.displayName,
                query: query,
                font: SplickTheme.Typography.headline,
                color: SplickTheme.Colors.textPrimary
            )
        case .message(let hit):
            Text(hit.peer.displayTitle)
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
        case .conversation(let conversation):
            HighlightedText(
                conversation.displayTitle,
                query: query,
                font: SplickTheme.Typography.headline,
                color: SplickTheme.Colors.textPrimary
            )
        }
    }

    @ViewBuilder
    private var subtitleView: some View {
        switch result {
        case .user(let user):
            HighlightedText(
                "@\(user.username)",
                query: query,
                font: SplickTheme.Typography.callout,
                color: SplickTheme.Colors.textSecondary
            )
        case .message(let hit):
            HighlightedText(
                hit.body,
                query: query,
                font: SplickTheme.Typography.callout,
                color: SplickTheme.Colors.textSecondary
            )
        case .conversation(let conversation):
            Text(conversation.lastMessage?.body ?? "")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
    }

    private var trailingTimestamp: String? {
        switch result {
        case .message(let hit):
            return hit.createdAt.relativeString
        case .conversation(let conversation):
            return conversation.lastMessage?.createdAt.relativeString
        case .user:
            return nil
        }
    }
}
