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
                ConversationListAvatar(
                    imageURL: conversation.groupAvatarUrl.flatMap(URL.init(string:)),
                    name: conversation.displayTitle
                )
            } else if let peer = conversation.peer {
                let presence = resolvedPresence(for: peer)
                ConversationListAvatar(
                    imageURL: peer.avatarUrl.flatMap(URL.init(string:)),
                    name: peer.displayTitle,
                    userId: peer.userId,
                    isOnline: PresenceDisplayPolicy.shouldShowOnlineIndicator(isOnline: presence.isOnline),
                    lastSeenLabel: PresenceDisplayPolicy.compactLastSeenLabel(
                        isOnline: presence.isOnline,
                        lastSeenAt: presence.lastSeenAt,
                        appLocale: languageService.locale
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
        if lastMessage.isSystemNotice || Self.looksLikeGroupMemberLeft(lastMessage) {
            let notice = (lastMessage.type == .groupMemberLeft || Self.looksLikeGroupMemberLeft(lastMessage))
                ? ChatMessage(
                    id: lastMessage.id,
                    conversationId: lastMessage.conversationId,
                    senderId: lastMessage.senderId,
                    senderDisplayName: lastMessage.senderDisplayName
                        ?? GroupSystemNoticePayload.memberLeftDisplayName(lastMessage.body),
                    body: lastMessage.body,
                    clientMessageId: lastMessage.clientMessageId,
                    createdAt: lastMessage.createdAt,
                    sequenceNo: lastMessage.sequenceNo,
                    reactions: lastMessage.reactions,
                    deliveryStatus: lastMessage.deliveryStatus,
                    imageAttachments: lastMessage.imageAttachments,
                    replyPreview: lastMessage.replyPreview,
                    type: .groupMemberLeft
                )
                : lastMessage
            return GroupSystemNoticeCopy.text(
                message: notice,
                currentUserId: currentUserSummary?.id,
                actorName: notice.senderDisplayName
                    ?? GroupSystemNoticePayload.memberLeftDisplayName(notice.body),
                languageService: languageService
            )
        }

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

    /// Leave notices persist the leaver display name as `body` (optionally marked).
    /// Recover when inbox mapping dropped `message_type` (raw name leaked into the row).
    private static func looksLikeGroupMemberLeft(_ message: ChatMessage) -> Bool {
        guard message.imageAttachments.isEmpty else { return false }
        if GroupSystemNoticePayload.isMemberLeft(message.body) { return true }
        let body = GroupSystemNoticePayload.memberLeftDisplayName(message.body)
        let sender = message.senderDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !body.isEmpty && !sender.isEmpty && body == sender
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
        let stored = presenceStore.state(for: peer.userId)
        let isOnline = (stored?.isOnline ?? false) || (peer.isOnline ?? false)
        let lastSeenAt = stored?.lastSeenAt ?? peer.lastSeenAt
        return (isOnline, lastSeenAt)
    }
}
