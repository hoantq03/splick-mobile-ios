import SwiftUI
import Common
import DesignSystem
import SplickDomain

struct ChatMessageListView: View {
    @Environment(\.messagingReactionPicker) private var reactionPicker

    @ObservedObject var viewModel: ChatThreadViewModel
    let messages: [ChatMessage]
    let currentUserId: UUID

    @State private var reactionTrayMessageId: UUID?
    @State private var bubbleFrames: [UUID: CGRect] = [:]

    var body: some View {
        let displayMessages = MessageTimelineGrouping.buildDisplayMessages(from: messages)

        ZStack(alignment: .topLeading) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(displayMessages) { item in
                            MessageBubble(
                                displayMessage: item,
                                isOutgoing: item.message.senderId == currentUserId,
                                currentUserId: currentUserId,
                                isHighlighted: viewModel.highlightedMessageId == item.message.id,
                                isFloatingSend: viewModel.newlySentMessageIds.contains(item.message.id),
                                floatSway: viewModel.floatSway(for: item.message.id),
                                onReact: { emoji in
                                    _ = viewModel.react(to: item.message.id, emoji: emoji)
                                },
                                onRetry: {
                                    Task { await viewModel.retrySend(messageId: item.message.id) }
                                },
                                onLongPress: {
                                    InteractionScrollLock.setLocked(true)
                                    reactionTrayMessageId = item.message.id
                                }
                            )
                            .id(item.message.id)
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
                .animation(ChatScrollAnimation.spring, value: messages.map(\.id))
                .onPreferenceChange(MessageBubbleFrameKey.self) { bubbleFrames = $0 }
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
                        dismissReactionTray()
                    }
                )
            }

            if let trayMessageId = reactionTrayMessageId,
               let frame = bubbleFrames[trayMessageId] {
                reactionTrayOverlay(messageId: trayMessageId, anchorFrame: frame)
            }
        }
    }

    @ViewBuilder
    private func reactionTrayOverlay(messageId: UUID, anchorFrame: CGRect) -> some View {
        Color.black.opacity(0.08)
            .ignoresSafeArea()
            .onTapGesture { dismissReactionTray() }

        MessageReactionTray(
            onReact: { emoji in
                _ = viewModel.react(to: messageId, emoji: emoji)
            },
            onOpenFullPicker: {
                dismissReactionTray()
                reactionPicker.present { emoji in
                    _ = viewModel.react(to: messageId, emoji: emoji)
                }
            },
            onDismiss: { dismissReactionTray() }
        )
        .position(
            x: anchorFrame.midX,
            y: max(anchorFrame.minY - 28, 60)
        )
    }

    private func dismissReactionTray() {
        reactionTrayMessageId = nil
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
