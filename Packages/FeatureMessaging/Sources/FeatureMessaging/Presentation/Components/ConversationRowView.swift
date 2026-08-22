import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

struct ConversationRowView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var presenceStore: PresenceStore
    @Environment(\.currentUserSummary) private var currentUserSummary

    let conversation: Conversation
    var reportsAnchorFrame = true
    var inboxTyping: InboxTypingState? = nil

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            if conversation.isGroup {
                AvatarView(
                    imageURL: conversation.groupAvatarUrl.flatMap(URL.init(string:)),
                    name: conversation.displayTitle,
                    size: .medium
                )
            } else if let peer = conversation.peer {
                AvatarWithPresenceView(
                    imageURL: peer.avatarUrl.flatMap(URL.init(string:)),
                    name: peer.displayTitle,
                    size: .medium,
                    userId: peer.userId,
                    showOnlineIndicator: PresenceDisplayPolicy.shouldShowOnlineIndicator(
                        isOnline: resolvedPresence(for: peer).isOnline
                    )
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(conversation.displayTitle)
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                    if conversation.isGroup, let memberCount = conversation.memberCount {
                        Text("(\(memberCount))")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                    Spacer()
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage.createdAt.relativeString)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                }

                HStack(spacing: SplickTheme.Spacing.xxs) {
                    Group {
                        if let inboxTyping {
                            inboxTypingPreview(inboxTyping)
                        } else if let presenceText = peerPresenceSubtitle {
                            Text(presenceText)
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        } else {
                            Text(lastMessagePreview)
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }
                    }
                    .animation(.easeInOut(duration: 0.24), value: inboxTyping != nil)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(SplickTheme.Typography.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    } else if !conversation.notificationsEnabled {
                        Image(systemName: "bell.slash")
                            .font(.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, SplickTheme.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            if reportsAnchorFrame {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ConversationRowAnchorFrameKey.self,
                            value: [conversation.id: geometry.frame(in: .global)]
                        )
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var lastMessagePreview: String {
        guard let lastMessage = conversation.lastMessage else { return "" }

        let sender = ConversationPreviewFormatter.senderLabel(
            for: lastMessage,
            currentUserId: currentUserSummary?.id,
            meLabel: languageService.text(.commonMe),
            fallbackDisplayName: conversation.peer?.displayTitle,
            unknownLabel: languageService.text(.messagingReplyUnknownSender)
        )

        let content: String
        switch ConversationPreviewFormatter.content(for: lastMessage) {
        case .text(let body):
            content = body.isEmpty ? languageService.text(.messagingReplyEmpty) : body
        case .emoji:
            content = languageService.text(.messagingConversationSentEmoji)
        case .gif:
            content = "GIF"
        case .images(let count):
            content = count == 1
                ? languageService.text(.messagingConversationSentImage)
                : languageService.format(.messagingConversationSentImages, count)
        }

        return "\(sender): \(content)"
    }

    @ViewBuilder
    private func inboxTypingPreview(_ state: InboxTypingState) -> some View {
        switch state.layout {
        case .direct:
            ConversationListTypingPreview(accessibilityLabel: state.typingBase)
        case .group(let username, let avatarURL):
            HStack(spacing: 6) {
                AvatarView(imageURL: avatarURL, name: username, size: .small)
                    .frame(width: 22, height: 22)
                Text(username)
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .lineLimit(1)
                ConversationListTypingPreview(accessibilityLabel: state.typingBase)
            }
        }
    }

    private func resolvedPresence(for peer: ConversationPeer) -> (isOnline: Bool, lastSeenAt: Date?) {
        if let state = presenceStore.state(for: peer.userId) {
            return (state.isOnline, state.lastSeenAt)
        }
        return (peer.isOnline ?? false, peer.lastSeenAt)
    }

    private var peerPresenceSubtitle: String? {
        guard !conversation.isGroup, let peer = conversation.peer else { return nil }
        let presence = resolvedPresence(for: peer)
        return PresenceDisplayPolicy.lastSeenText(
            isOnline: presence.isOnline,
            lastSeenAt: presence.lastSeenAt,
            appLocale: languageService.locale
        )
    }
}
