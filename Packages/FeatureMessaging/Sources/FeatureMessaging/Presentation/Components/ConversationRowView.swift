import SwiftUI
import Common
import DesignSystem
import SplickDomain

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(
                imageURL: conversation.peer?.avatarUrl.flatMap(URL.init(string:)),
                name: conversation.peer?.displayTitle ?? "",
                size: .medium
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(conversation.peer?.displayTitle ?? String(conversation.id.uuidString.prefix(8)))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage.createdAt.relativeString)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                }

                HStack {
                    Text(conversation.lastMessage?.body ?? "")
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
}
