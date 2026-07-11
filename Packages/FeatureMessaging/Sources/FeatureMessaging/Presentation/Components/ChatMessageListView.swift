import SwiftUI
import UIKit
import Common
import DesignSystem
import SplickDomain

struct ChatMessageListView: View {
    @Environment(\.messagingReactionPicker) private var reactionPicker

    @ObservedObject var viewModel: ChatThreadViewModel
    let messages: [ChatMessage]
    let currentUserId: UUID
    let senderDisplayName: (ChatMessage) -> String
    let onRequestComposerFocus: () -> Void

    @State private var reactionFocusMessageId: UUID?
    @State private var reactionAnchorFrames: [UUID: CGRect] = [:]

    private static let longPressImpact = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        let displayMessages = MessageTimelineGrouping.buildDisplayMessages(from: messages)

        ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(displayMessages) { item in
                            MessageBubble(
                                displayMessage: item,
                                isOutgoing: item.message.senderId == currentUserId,
                                currentUserId: currentUserId,
                                isHighlighted: viewModel.highlightedMessageId == item.message.id,
                                isFloatingSend: viewModel.newlySentMessageIds.contains(item.message.clientMessageId),
                                floatSway: viewModel.floatSway(for: item.message.clientMessageId),
                                onReact: { emoji in
                                    _ = viewModel.react(to: item.message.id, emoji: emoji)
                                },
                                onRetry: {
                                    Task { await viewModel.retrySend(messageId: item.message.id) }
                                },
                                onLongPress: {
                                    openReactionFocus(for: item)
                                },
                                onReply: {
                                    beginReply(to: item.message)
                                }
                            )
                            .id(item.message.clientMessageId)
                            .transition(ChatScrollAnimation.messageInsert)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(ChatScrollAnimation.bottomAnchor)
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.sm)
                }
                .modifier(ChatBottomScrollAnchorModifier())
                .animation(ChatScrollAnimation.spring, value: messages.map(\.clientMessageId))
                .onPreferenceChange(MessageReactionAnchorFrameKey.self) { frames in
                    reactionAnchorFrames.merge(frames) { _, new in new }
                }

                GeometryReader { overlayGeometry in
                    if reactionFocusMessageId != nil,
                       let focusContext = reactionFocusContext(
                        in: displayMessages,
                        overlayOrigin: overlayGeometry.frame(in: .global).origin
                       ) {
                        MessageReactionFocusOverlay(
                            context: focusContext,
                            onReact: { emoji in
                                _ = viewModel.react(to: focusContext.messageId, emoji: emoji)
                            },
                            onReply: {
                                guard let item = displayMessages.first(where: { $0.message.id == focusContext.messageId }) else {
                                    return
                                }
                                beginReply(to: item.message)
                            },
                            onOpenFullPicker: {
                                dismissReactionFocus()
                                reactionPicker.present { emoji in
                                    _ = viewModel.react(to: focusContext.messageId, emoji: emoji)
                                }
                            },
                            onDismiss: { dismissReactionFocus() }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(100)
                    }
                }
                .allowsHitTesting(reactionFocusMessageId != nil)
            }
            .animation(MessageReactionTrayMotion.present, value: reactionFocusMessageId)
            .onAppear {
                if viewModel.scrollToMessageToken == 0 {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onChange(of: viewModel.scrollToBottomToken) { token in
                guard token > 0 else { return }
                scrollToBottom(proxy: proxy, animated: token > 1)
            }
            .onChange(of: viewModel.scrollToMessageToken) { token in
                guard token > 0, let targetId = viewModel.highlightedMessageId else { return }
                scrollToMessage(targetId, proxy: proxy)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onChanged { _ in
                    dismissReactionFocus()
                }
            )
        }
    }

    private func reactionFocusContext(
        in displayMessages: [DisplayMessage],
        overlayOrigin: CGPoint
    ) -> MessageReactionFocusContext? {
        guard let messageId = reactionFocusMessageId,
              let globalFrame = reactionAnchorFrames[messageId],
              globalFrame.width > 1,
              globalFrame.height > 1,
              let item = displayMessages.first(where: { $0.message.id == messageId })
        else { return nil }

        let localFrame = globalFrame.offsetBy(dx: -overlayOrigin.x, dy: -overlayOrigin.y)

        return MessageReactionFocusContext(
            messageId: messageId,
            isOutgoing: item.message.senderId == currentUserId,
            frame: localFrame
        )
    }

    private func openReactionFocus(for item: DisplayMessage) {
        guard reactionFocusMessageId == nil else { return }
        Self.longPressImpact.impactOccurred()
        InteractionScrollLock.setLocked(true)
        withAnimation(MessageReactionTrayMotion.present) {
            reactionFocusMessageId = item.message.id
        }
    }

    private func beginReply(to message: ChatMessage) {
        dismissReactionFocus()
        viewModel.beginReply(to: message, senderDisplayName: senderDisplayName(message))
        onRequestComposerFocus()
    }

    private func dismissReactionFocus() {
        guard reactionFocusMessageId != nil else { return }
        withAnimation(MessageReactionTrayMotion.dismiss) {
            reactionFocusMessageId = nil
        }
        InteractionScrollLock.forceUnlock()
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessageId = viewModel.messages.last?.id else { return }

        func performScroll(useAnimation: Bool) {
            if useAnimation {
                withAnimation(ChatScrollAnimation.spring) {
                    proxy.scrollTo(lastMessageId, anchor: .bottom)
                    proxy.scrollTo(ChatScrollAnimation.bottomAnchor, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastMessageId, anchor: .bottom)
                proxy.scrollTo(ChatScrollAnimation.bottomAnchor, anchor: .bottom)
            }
        }

        let delays: [TimeInterval] = animated ? [0, 0.05, 0.12] : [0, 0.05, 0.12, 0.25]
        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                performScroll(useAnimation: animated && index > 0)
            }
        }
    }

    private func scrollToMessage(_ messageId: UUID, proxy: ScrollViewProxy) {
        let delays: [TimeInterval] = [0, 0.05, 0.12, 0.25]
        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if index == 0 {
                    proxy.scrollTo(messageId, anchor: .center)
                } else {
                    withAnimation(ChatScrollAnimation.spring) {
                        proxy.scrollTo(messageId, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct ChatBottomScrollAnchorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.defaultScrollAnchor(.bottom)
        } else {
            content
        }
    }
}
