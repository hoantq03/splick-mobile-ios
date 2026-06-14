import SwiftUI
import DesignSystem
import SplickDomain

struct ChatMessageListView: View {
    @ObservedObject var viewModel: ChatThreadViewModel
    let messages: [ChatMessage]
    let currentUserId: UUID

    var body: some View {
        let displayMessages = MessageTimelineGrouping.buildDisplayMessages(from: messages)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(displayMessages) { item in
                        MessageBubble(
                            displayMessage: item,
                            isOutgoing: item.message.senderId == currentUserId,
                            onReact: { emoji in
                                _ = viewModel.react(to: item.message.id, emoji: emoji)
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
            .onAppear {
                // Token may already be set before this view mounts; onChange alone misses initial open.
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: viewModel.scrollToBottomToken) { token in
                guard token > 0 else { return }
                scrollToBottom(proxy: proxy, animated: token > 1)
            }
        }
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

        // Chat content height is unknown until layout finishes — retry across several frames.
        let delays: [TimeInterval] = animated ? [0, 0.05, 0.12] : [0, 0.05, 0.12, 0.25]
        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                performScroll(useAnimation: animated && index > 0)
            }
        }
    }
}

/// Keeps the scroll view anchored to the bottom on first layout (iOS 17+).
private struct ChatBottomScrollAnchorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.defaultScrollAnchor(.bottom)
        } else {
            content
        }
    }
}
