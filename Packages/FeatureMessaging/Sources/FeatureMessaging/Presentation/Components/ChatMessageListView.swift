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
    /// Fresh identity each open so `@State isRevealed` cannot stick across odd/even mounts.
    @State private var reactionFocusSession = UUID()
    /// Snapshot at open — opacity-0 source bubble can stop publishing a usable frame.
    @State private var reactionFocusFrozenFrame: CGRect?
    /// Ignore drag / dim-tap dismiss until the long-press finger has lifted.
    @State private var reactionFocusDismissArmed = false
    @State private var reactionAnchorFrames: [UUID: CGRect] = [:]
    @State private var timestampRevealTranslation: CGFloat = 0
    /// Once a drag is classified as bubble-reply vs whitespace-reveal, stick with it.
    @State private var timestampRevealSession: TimestampRevealSession = .undecided

    private static let longPressImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let reactionFocusDismissArmDelay: TimeInterval = 0.45

    private enum TimestampRevealSession {
        case undecided
        case revealing
        case ignored
    }

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
                                timestampRevealTranslation: timestampRevealTranslation,
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
                            .opacity(reactionFocusMessageId == item.message.id ? 0 : 1)
                            .allowsHitTesting(reactionFocusMessageId != item.message.id)
                            .id(item.message.clientMessageId)
                            .transition(ChatScrollAnimation.messageInsert)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(ChatScrollAnimation.bottomAnchor)
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                }
                .modifier(ChatBottomScrollAnchorModifier())
                .animation(ChatScrollAnimation.spring, value: messages.map(\.clientMessageId))
                .onPreferenceChange(MessageReactionAnchorFrameKey.self) { frames in
                    for (id, frame) in frames where frame.width > 1 && frame.height > 1 {
                        reactionAnchorFrames[id] = frame
                    }
                }
                .simultaneousGesture(timestampRevealGesture)

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
                                dismissReactionFocus(force: true)
                                reactionPicker.present { emoji in
                                    _ = viewModel.react(to: focusContext.messageId, emoji: emoji)
                                }
                            },
                            onDismiss: { dismissReactionFocus(force: false) },
                            onForceDismiss: { dismissReactionFocus(force: true) }
                        )
                        .id(reactionFocusSession)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(100)
                    }
                }
                .allowsHitTesting(reactionFocusMessageId != nil)
            }
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
                    dismissReactionFocus(force: false)
                }
            )
        }
    }

    private var timestampRevealGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)

                switch timestampRevealSession {
                case .ignored:
                    return
                case .undecided:
                    guard abs(horizontal) > vertical * 1.15 else { return }
                    if isTouchOnMessageBubble(value.startLocation) {
                        timestampRevealSession = .ignored
                        return
                    }
                    timestampRevealSession = .revealing
                case .revealing:
                    break
                }

                let signed = horizontal < 0 ? -abs(horizontal) : abs(horizontal)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    // Keep 1:1 with the finger; bubbles clip to the label width.
                    timestampRevealTranslation = signed
                }
            }
            .onEnded { _ in
                let shouldReset = timestampRevealSession == .revealing
                timestampRevealSession = .undecided
                guard shouldReset else { return }
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                    timestampRevealTranslation = 0
                }
            }
    }

    private func isTouchOnMessageBubble(_ globalPoint: CGPoint) -> Bool {
        reactionAnchorFrames.values.contains { frame in
            frame.insetBy(dx: -6, dy: -4).contains(globalPoint)
        }
    }

    private func reactionFocusContext(
        in displayMessages: [DisplayMessage],
        overlayOrigin: CGPoint
    ) -> MessageReactionFocusContext? {
        guard let messageId = reactionFocusMessageId,
              let globalFrame = reactionFocusFrozenFrame ?? reactionAnchorFrames[messageId],
              globalFrame.width > 1,
              globalFrame.height > 1,
              let item = displayMessages.first(where: { $0.message.id == messageId })
        else { return nil }

        let localFrame = globalFrame.offsetBy(dx: -overlayOrigin.x, dy: -overlayOrigin.y)

        return MessageReactionFocusContext(
            messageId: messageId,
            isOutgoing: item.message.senderId == currentUserId,
            frame: localFrame,
            displayMessage: item,
            currentUserId: currentUserId
        )
    }

    private func openReactionFocus(for item: DisplayMessage) {
        // Recover from a stuck focus id (overlay never mounted / never armed dismiss).
        if reactionFocusMessageId != nil {
            dismissReactionFocus(force: true)
        }
        guard let globalFrame = reactionAnchorFrames[item.message.id],
              globalFrame.width > 1,
              globalFrame.height > 1
        else { return }

        let session = UUID()
        reactionFocusSession = session
        reactionFocusFrozenFrame = globalFrame
        reactionFocusDismissArmed = false
        Self.longPressImpact.impactOccurred()
        InteractionScrollLock.setLocked(true)
        reactionFocusMessageId = item.message.id

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reactionFocusDismissArmDelay) {
            guard reactionFocusSession == session, reactionFocusMessageId != nil else { return }
            reactionFocusDismissArmed = true
        }
    }

    private func beginReply(to message: ChatMessage) {
        dismissReactionFocus(force: true)
        viewModel.beginReply(to: message, senderDisplayName: senderDisplayName(message))
        onRequestComposerFocus()
    }

    private func dismissReactionFocus(force: Bool) {
        guard reactionFocusMessageId != nil else { return }
        guard force || reactionFocusDismissArmed else { return }
        reactionFocusMessageId = nil
        reactionFocusFrozenFrame = nil
        reactionFocusDismissArmed = false
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
