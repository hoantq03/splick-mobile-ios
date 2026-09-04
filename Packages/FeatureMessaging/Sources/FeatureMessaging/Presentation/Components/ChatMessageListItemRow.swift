import SwiftUI
import DesignSystem
import Localization
import SplickDomain

/// One message cell in the thread list (bubble + optional typing row below).
struct ChatMessageListItemRow: View {
    @EnvironmentObject private var languageService: LanguageService

    let item: DisplayMessage
    let isOutgoing: Bool
    let currentUserId: UUID
    let listRowWidth: CGFloat
    let timestampRevealTranslation: CGFloat
    let replySwipeTranslation: CGFloat
    let isReactionFocusHidden: Bool
    let isHighlighted: Bool
    let highlightPulseToken: Int
    let isFloatingSend: Bool
    let floatSway: CGFloat
    let showsReadReceiptAvatar: Bool
    let readReceiptPeerAvatarURL: URL?
    let readReceiptPeerName: String
    let senderAvatarURL: URL?
    let senderAvatarName: String
    let suppressSenderAvatar: Bool
    let reportsSenderAvatarAnchor: Bool
    let messageContinuesIntoTyping: Bool
    let showsTypingIndicator: Bool
    let showAvatarHandoffOverlay: Bool
    let typingUserId: UUID?
    let typingSenderAvatarURL: URL?
    let typingSenderDisplayName: String
    let hasCompletedInitialBottomScroll: Bool
    let allowsThreadInteraction: Bool
    let onReact: (String) -> Void
    let onRetry: () -> Void
    let onLongPress: () -> Void
    let onReply: (() -> Void)?
    let onQuotedReply: (UUID) -> Void
    let onTypingRowAppear: () -> Void
    let actorDisplayName: String
    let isQuotedMessageRecalled: (UUID) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            if item.showsTimeSeparator {
                MessageTimeSeparatorLabel(date: item.message.createdAt)
            }

            if GroupSystemNoticePayload.displaysAsSystemNotice(item.message) {
                GroupSystemNoticeLabel(
                    text: GroupSystemNoticeCopy.text(
                        message: item.message,
                        currentUserId: currentUserId,
                        actorName: actorDisplayName,
                        languageService: languageService
                    )
                )
            } else {
                messageBubble
                typingRowIfNeeded
            }
        }
    }

    private var messageBubble: some View {
        MessageBubble(
            displayMessage: item,
            isOutgoing: isOutgoing,
            currentUserId: currentUserId,
            isHighlighted: isHighlighted,
            highlightPulseToken: highlightPulseToken,
            isFloatingSend: isFloatingSend,
            floatSway: floatSway,
            contentMaxWidth: MessageThreadRowLayout.contentMaxWidth(forRowWidth: listRowWidth),
            timestampRevealTranslation: timestampRevealTranslation,
            replySwipeTranslation: replySwipeTranslation,
            onReact: onReact,
            onRetry: onRetry,
            onLongPress: onLongPress,
            onReply: onReply,
            onQuotedReply: onQuotedReply,
            readReceiptPeerAvatarURL: readReceiptPeerAvatarURL,
            readReceiptPeerName: readReceiptPeerName,
            showsReadReceiptAvatar: showsReadReceiptAvatar,
            senderAvatarURL: senderAvatarURL,
            senderAvatarName: senderAvatarName,
            suppressSenderAvatar: suppressSenderAvatar,
            reportsSenderAvatarAnchor: reportsSenderAvatarAnchor,
            isQuotedMessageRecalled: isQuotedMessageRecalled
        )
        .opacity(isReactionFocusHidden ? 0 : 1)
        .allowsHitTesting(!isReactionFocusHidden)
    }

    @ViewBuilder
    private var typingRowIfNeeded: some View {
        if messageContinuesIntoTyping && showsTypingIndicator {
            MessageTypingIndicatorBubble(
                senderAvatarURL: typingSenderAvatarURL,
                senderAvatarName: typingSenderDisplayName,
                senderUserId: typingUserId,
                showsSenderAvatar: !showAvatarHandoffOverlay,
                continuesMessageCluster: true,
                reportsSenderAvatarAnchor: true
            )
            .id("typing-indicator")
            .onAppear(perform: onTypingRowAppear)
            .transition(
                hasCompletedInitialBottomScroll
                    ? ChatScrollAnimation.typingRow
                    : .identity
            )
        }
    }
}
