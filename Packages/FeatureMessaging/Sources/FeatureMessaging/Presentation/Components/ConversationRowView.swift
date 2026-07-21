import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

struct ConversationRowView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.currentUserSummary) private var currentUserSummary

    let conversation: Conversation

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            if conversation.isGroup {
                AvatarView(
                    imageURL: conversation.groupAvatarUrl.flatMap(URL.init(string:)),
                    name: conversation.displayTitle,
                    size: .medium
                )
            } else {
                AvatarView(
                    imageURL: conversation.peer?.avatarUrl.flatMap(URL.init(string:)),
                    name: conversation.peer?.displayTitle ?? "",
                    size: .medium
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

                HStack {
                    Text(lastMessagePreview)
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(SplickTheme.Typography.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, SplickTheme.Spacing.xs)
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
        case .images(let count):
            content = count == 1
                ? languageService.text(.messagingConversationSentImage)
                : languageService.format(.messagingConversationSentImages, count)
        }

        return "\(sender): \(content)"
    }
}
