import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

struct ConversationRowView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.currentUserSummary) private var currentUserSummary

    let conversation: Conversation
    var reportsAnchorFrame = true
    var typingPreview: String? = nil

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
                    Group {
                        if let typingPreview {
                            ConversationListTypingPreview(
                                textPrefix: MessagingTypingCopy.stripTrailingEllipsis(typingPreview)
                            )
                            .font(SplickTheme.Typography.callout.italic())
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        } else {
                            Text(lastMessagePreview)
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }
                    }
                    .animation(.easeInOut(duration: 0.24), value: typingPreview != nil)
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
}
