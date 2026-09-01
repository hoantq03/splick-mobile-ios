import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain

struct ChatMessageListView: View {
    @EnvironmentObject private var languageService: LanguageService

    @ObservedObject var viewModel: ChatThreadViewModel
    let messages: [ChatMessage]
    let currentUserId: UUID
    let senderDisplayName: (ChatMessage) -> String
    let userDisplayName: (UUID) -> String
    let onRequestComposerFocus: () -> Void
    var onDismissKeyboard: () -> Void = {}
    var peerAvatarURL: URL? = nil
    var peerDisplayName: String = ""
    var showsPeerReadAvatar: Bool = false
    var conversationId: UUID? = nil
    var bottomOverlayInset: CGFloat = 8
    var onOpenDetails: (ChatMessage) -> Void = { _ in }
    /// When false (removed from group / blocked), hide Reply and reactions; Copy + Details remain.
    var allowsThreadInteraction: Bool = true
    var onBeginEdit: (ChatMessage) -> Void = { _ in }
    var onRequestRecall: (UUID) -> Void = { _ in }
    /// Window-space focus presentation — drawn by `ChatThreadView` so the dimmer covers the composer.
    @Binding var reactionFocus: MessageReactionFocusContext?
    /// Fresh identity each open so `@State isRevealed` cannot stick across odd/even mounts.
    @State private var reactionFocusSession = UUID()
    /// Ignore drag / dim-tap dismiss until the long-press finger has lifted.
    @State private var reactionFocusDismissArmed = false
    @State private var timestampRevealTranslation: CGFloat = 0
    /// Driven from the list pan so bubble-local DragGesture cannot steal vertical scroll.
    @State private var replySwipeMessageId: UUID?
    @State private var replySwipeTranslation: CGFloat = 0
    /// Once a drag is classified (scroll / reply / timestamp), stick with it.
    @State private var listPanSession: ListPanSession = .undecided
    @State private var listRowWidth: CGFloat = 0
    @State private var hasCompletedInitialBottomScroll = false
    @State private var initialOpenBottomScrollPending = true
    /// User scrolled away during open — stop API/layout retries from yanking back to bottom.
    @State private var userReleasedInitialPin = false
    @State private var lastHandledScrollToBottomToken = 0
    @State private var lastAnchoredMessageClientId: UUID?
    @State private var messageAvatarCenter: CGPoint?
    @State private var typingAvatarCenter: CGPoint?
    @State private var avatarHandoffProgress: CGFloat = 0

    private static let longPressImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let replySwipeImpact = UIImpactFeedbackGenerator(style: .light)
    private static let reactionFocusDismissArmDelay: TimeInterval = 0.45
    private static let replySwipeThreshold: CGFloat = 56
    /// Past the icon slot (46) so threshold is reachable while reveal stays 1:1.
    private static let replySwipeMaxOffset: CGFloat = 72
    /// Leading strip reserved for strict edge-only interactive pop (must match
    /// `splickEdgeOnlyInteractivePop` default). 1pt so timestamp / reply own
    /// almost the full leading edge; only a hairline triggers back.
    private static let navigationBackEdgeWidth: CGFloat = 1

    private var reactionFocusMessageId: UUID? {
        reactionFocus?.messageId
    }

    private var latestReadOutgoingMessageId: UUID? {
        MessageReadReceiptPresentation.latestReadOutgoingMessageId(
            in: messages,
            currentUserId: currentUserId
        )
    }

    private enum ListPanSession {
        case undecided
        case revealingTimestamps
        case replySwiping(messageId: UUID, isOutgoing: Bool)
        /// Vertical pan — leave scrolling to ScrollView.
        case scrolling
    }

    var body: some View {
        let displayMessages = MessageTimelineGrouping.buildDisplayMessages(from: messages)
        let typingContext = makeTypingContext()

        return ScrollViewReader { proxy in
            chatScrollContainer(
                proxy: proxy,
                displayMessages: displayMessages,
                typingContext: typingContext
            )
            .onChange(of: reactionFocus == nil) { isCleared in
                if isCleared {
                    InteractionScrollLock.forceUnlock()
                }
            }
        }
    }

    private struct ChatTypingContext {
        let userId: UUID?
        let showsIndicator: Bool
        let handoffEligible: Bool
        let showAvatarHandoffOverlay: Bool
    }

    private func makeTypingContext() -> ChatTypingContext {
        let typingUserId = viewModel.typingUserIds.first
        let showsTypingIndicator = !viewModel.typingUserIds.isEmpty
        let lastMessage = messages.last
        let typingHandoffEligible = typingUserId != nil
            && lastMessage?.senderId == typingUserId
            && lastMessage?.senderId != currentUserId
            && lastMessage.map { !GroupSystemNoticePayload.displaysAsSystemNotice($0) } ?? true
        let showAvatarHandoffOverlay = typingHandoffEligible
            && (showsTypingIndicator || avatarHandoffProgress > 0.01)
            && messageAvatarCenter != nil
        return ChatTypingContext(
            userId: typingUserId,
            showsIndicator: showsTypingIndicator,
            handoffEligible: typingHandoffEligible,
            showAvatarHandoffOverlay: showAvatarHandoffOverlay
        )
    }

    @ViewBuilder
    private func chatScrollContainer(
        proxy: ScrollViewProxy,
        displayMessages: [DisplayMessage],
        typingContext: ChatTypingContext
    ) -> some View {
            ZStack {
                ScrollView {
                    messagesLazyStack(
                        displayMessages: displayMessages,
                        typingContext: typingContext,
                        proxy: proxy
                    )
                }
                .onChange(of: typingContext.showsIndicator) { isTyping in
                    guard typingContext.handoffEligible else {
                        avatarHandoffProgress = 0
                        return
                    }
                    withAnimation(ChatScrollAnimation.spring) {
                        avatarHandoffProgress = isTyping ? 1 : 0
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .overlay {
                    ChatListHorizontalPanInstaller(
                        isEnabled: reactionFocusMessageId == nil,
                        edgeExclusionWidth: Self.navigationBackEdgeWidth,
                        onChanged: handleListPanChanged,
                        onEnded: handleListPanEnded,
                        onNearBottomChanged: { near in
                            if near {
                                userReleasedInitialPin = false
                                viewModel.onViewportReturnedToBottom()
                            }
                        },
                        onUserScrolledAwayFromBottom: {
                            guard !initialOpenBottomScrollPending else { return }
                            userReleasedInitialPin = true
                            viewModel.onViewportLeftBottom()
                        }
                    )
                    .allowsHitTesting(false)
                }
                .modifier(ChatThreadScrollPositionModifier())
                .onChange(of: viewModel.prependAnchorMessageId) { anchorId in
                    guard let anchorId else { return }
                    // Keep visual position after older messages are prepended.
                    DispatchQueue.main.async {
                        proxy.scrollTo(anchorId, anchor: .top)
                        viewModel.clearPrependAnchor()
                    }
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        hideKeyboard()
                        onDismissKeyboard()
                    },
                    including: reactionFocusMessageId == nil ? .all : .none
                )
            }
            .overlayPreferenceValue(ChatReadReceiptAnchorKey.self) { anchor in
                ChatReadReceiptAvatarOverlay(
                    anchor: anchor,
                    avatarURL: peerAvatarURL,
                    avatarName: peerDisplayName,
                    isVisible: showsPeerReadAvatar && latestReadOutgoingMessageId != nil
                )
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .task(id: bottomScrollTaskKey) {
                guard viewModel.scrollToMessageToken == 0 else { return }
                guard viewModel.highlightedMessageId == nil else { return }
                guard viewModel.prependAnchorMessageId == nil else { return }
                guard !viewModel.messages.isEmpty else { return }

                let tokenIncreased = viewModel.scrollToBottomToken > lastHandledScrollToBottomToken
                let isInitial = !hasCompletedInitialBottomScroll || initialOpenBottomScrollPending
                if !isInitial, !tokenIncreased, !viewModel.isNearBottom { return }

                if tokenIncreased {
                    lastHandledScrollToBottomToken = viewModel.scrollToBottomToken
                    userReleasedInitialPin = false
                }

                if isInitial {
                    await scrollToBottomUntilVisible(
                        proxy: proxy,
                        animated: false
                    )
                } else {
                    scrollToBottom(proxy: proxy, animated: tokenIncreased)
                    try? await Task.sleep(for: .milliseconds(50))
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onChange(of: viewModel.messages.last?.clientMessageId) { newLast in
                guard initialOpenBottomScrollPending, let newLast else { return }
                guard newLast != lastAnchoredMessageClientId else { return }
                lastAnchoredMessageClientId = newLast
                Task {
                    await scrollToBottomUntilVisible(
                        proxy: proxy,
                        animated: false
                    )
                }
            }
            .onChange(of: viewModel.scrollToBottomToken) { token in
                guard token > lastHandledScrollToBottomToken else { return }
                guard viewModel.scrollToMessageToken == 0 else { return }
                guard viewModel.highlightedMessageId == nil else { return }
                lastHandledScrollToBottomToken = token
                scrollToBottom(proxy: proxy, animated: hasCompletedInitialBottomScroll)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            ) { notification in
                guard viewModel.scrollToMessageToken == 0 else { return }
                guard viewModel.highlightedMessageId == nil else { return }
                // Only keep the latest in view if the user is already at the bottom.
                // Focusing the composer for reply must not jump away from the replied message.
                guard viewModel.isNearBottom || initialOpenBottomScrollPending else { return }
                scrollToBottom(proxy: proxy, animated: false)
                let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?
                    .doubleValue ?? 0.25
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onChange(of: conversationId) { _ in
                hasCompletedInitialBottomScroll = false
                initialOpenBottomScrollPending = true
                userReleasedInitialPin = false
                lastHandledScrollToBottomToken = 0
                lastAnchoredMessageClientId = nil
                viewModel.userReturnedToLatest()
            }
            .onChange(of: viewModel.messages.count) { count in
                guard count > 0 else { return }
                if initialOpenBottomScrollPending {
                    scrollToBottom(proxy: proxy, animated: false)
                    return
                }
                guard viewModel.autoFollowLatest else { return }
                scrollToBottom(proxy: proxy, animated: hasCompletedInitialBottomScroll)
            }
            .onChange(of: viewModel.scrollToMessageToken) { token in
                guard token > 0, let targetId = viewModel.highlightedMessageId else { return }
                scrollToMessage(targetId, proxy: proxy)
            }
    }

    @ViewBuilder
    private func messagesLazyStack(
        displayMessages: [DisplayMessage],
        typingContext: ChatTypingContext,
        proxy: ScrollViewProxy
    ) -> some View {
        let lastMessage = messages.last

        LazyVStack(spacing: 0) {
            if viewModel.isLoadingOlder {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SplickTheme.Spacing.sm)
            }

            ForEach(displayMessages) { item in
                messageListRow(
                    item: item,
                    displayMessages: displayMessages,
                    lastMessage: lastMessage,
                    typingContext: typingContext
                )
            }

            if typingContext.showsIndicator && !typingContext.handoffEligible {
                standaloneTypingIndicator(typingUserId: typingContext.userId)
            }

            Color.clear
                .frame(height: 1)
                .id(ChatScrollAnimation.bottomAnchor)
                .onAppear {
                    viewModel.noteNearBottom(true)
                    if initialOpenBottomScrollPending {
                        markInitialBottomScrollComplete()
                    }
                }
        }
        .coordinateSpace(name: "chatContent")
        .overlay {
            GeometryReader { _ in
                if typingContext.showAvatarHandoffOverlay {
                    TypingAvatarHandoffOverlay(
                        avatarURL: typingSenderAvatarURL(typerId: typingContext.userId),
                        avatarName: typingSenderDisplayName(typerId: typingContext.userId),
                        userId: typingContext.userId,
                        messageCenter: messageAvatarCenter,
                        typingCenter: typingAvatarCenter,
                        progress: avatarHandoffProgress
                    )
                }
            }
            .allowsHitTesting(false)
        }
        .onPreferenceChange(TypingAvatarAnchorPreferenceKey.self) { anchors in
            if let message = anchors[.message] {
                messageAvatarCenter = message
            }
            if let typing = anchors[.typing] {
                typingAvatarCenter = typing
            }
        }
        .padding(.horizontal, MessageThreadRowLayout.listHorizontalPadding)
        .padding(.top, SplickTheme.Spacing.sm)
        .padding(.bottom, SplickTheme.Spacing.sm + bottomOverlayInset)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: ChatListRowWidthKey.self, value: geo.size.width)
            }
        }
        .onPreferenceChange(ChatListRowWidthKey.self) { width in
            let rowWidth = max(width - MessageThreadRowLayout.listHorizontalPadding * 2, 1)
            if abs(rowWidth - listRowWidth) > 0.5 {
                let wasUnmeasured = listRowWidth <= 1
                listRowWidth = rowWidth
                if wasUnmeasured, rowWidth > 1, initialOpenBottomScrollPending {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
        }
        .modifier(ChatThreadScrollTargetLayoutModifier())
        .onAppear { prefetchRecentThreadMedia() }
        .onChange(of: messages.suffix(12).map(\.id)) { _ in
            prefetchRecentThreadMedia()
        }
        .animation(ChatScrollAnimation.spring, value: viewModel.typingUserIds)
    }

    @ViewBuilder
    private func messageListRow(
        item: DisplayMessage,
        displayMessages: [DisplayMessage],
        lastMessage: ChatMessage?,
        typingContext: ChatTypingContext
    ) -> some View {
        let isLastDisplayMessage = item.id == displayMessages.last?.id
        let messageContinuesIntoTyping = typingContext.handoffEligible
            && isLastDisplayMessage
            && item.message.id == lastMessage?.id
        let isOutgoing = item.message.senderId == currentUserId
        let replySwipe = replySwipeMessageId == item.message.id ? replySwipeTranslation : 0
        let isQuotedMessageRecalled: (UUID) -> Bool = { messageId in
            messages.contains { $0.id == messageId && $0.recalled }
        }

        ChatMessageListItemRow(
            item: item,
            isOutgoing: isOutgoing,
            currentUserId: currentUserId,
            listRowWidth: listRowWidth,
            timestampRevealTranslation: timestampRevealTranslation,
            replySwipeTranslation: replySwipe,
            isReactionFocusHidden: reactionFocusMessageId == item.message.id,
            isHighlighted: viewModel.highlightedMessageId == item.message.id,
            highlightPulseToken: viewModel.scrollToMessageToken,
            isFloatingSend: viewModel.newlySentMessageIds.contains(item.message.clientMessageId),
            floatSway: viewModel.floatSway(for: item.message.clientMessageId),
            showsReadReceiptAvatar: showsPeerReadAvatar && item.message.id == latestReadOutgoingMessageId,
            readReceiptPeerAvatarURL: peerAvatarURL,
            readReceiptPeerName: peerDisplayName,
            senderAvatarURL: senderAvatarURL(for: item.message),
            senderAvatarName: senderDisplayName(item.message),
            suppressSenderAvatar: messageContinuesIntoTyping && typingContext.showAvatarHandoffOverlay,
            reportsSenderAvatarAnchor: messageContinuesIntoTyping,
            messageContinuesIntoTyping: messageContinuesIntoTyping,
            showsTypingIndicator: typingContext.showsIndicator,
            showAvatarHandoffOverlay: typingContext.showAvatarHandoffOverlay,
            typingUserId: typingContext.userId,
            typingSenderAvatarURL: typingSenderAvatarURL(typerId: typingContext.userId),
            typingSenderDisplayName: typingSenderDisplayName(typerId: typingContext.userId),
            hasCompletedInitialBottomScroll: hasCompletedInitialBottomScroll,
            allowsThreadInteraction: allowsThreadInteraction,
            onReact: { emoji in
                guard allowsThreadInteraction else { return }
                _ = viewModel.react(to: item.message.id, emoji: emoji)
            },
            onRetry: {
                Task { await viewModel.retrySend(messageId: item.message.id) }
            },
            onLongPress: {
                openReactionFocus(for: item)
            },
            onReply: allowsThreadInteraction && !item.message.recalled
                ? { beginReply(to: item.message) }
                : nil,
            onQuotedReply: { originId in
                Task { await viewModel.revealSearchedMessage(id: originId) }
            },
            onTypingRowAppear: {
                guard initialOpenBottomScrollPending else { return }
                markInitialBottomScrollComplete()
            },
            actorDisplayName: userDisplayName(item.message.senderId),
            isQuotedMessageRecalled: isQuotedMessageRecalled
        )
        .id(item.message.clientMessageId)
        .onAppear {
            guard item.message.id == messages.first?.id else { return }
            Task { await viewModel.loadOlderMessagesIfNeeded(current: item.message) }
        }
    }

    @ViewBuilder
    private func standaloneTypingIndicator(typingUserId: UUID?) -> some View {
        MessageTypingIndicatorBubble(
            senderAvatarURL: typingSenderAvatarURL(typerId: typingUserId),
            senderAvatarName: typingSenderDisplayName(typerId: typingUserId),
            senderUserId: typingUserId,
            showsSenderAvatar: true,
            continuesMessageCluster: false
        )
        .id("typing-indicator")
        .onAppear {
            guard initialOpenBottomScrollPending else { return }
            markInitialBottomScrollComplete()
        }
        .transition(
            hasCompletedInitialBottomScroll
                ? ChatScrollAnimation.typingRow
                : .identity
        )
    }

    private var bottomScrollTaskKey: String {
        let conversation = conversationId?.uuidString ?? "none"
        let last = viewModel.messages.last?.clientMessageId.uuidString ?? "none"
        let count = viewModel.messages.count
        return "\(conversation)-\(last)-\(count)-\(viewModel.scrollToBottomToken)"
    }

    private func resolvedBottomScrollTarget() -> AnyHashable? {
        if let last = viewModel.messages.last?.clientMessageId { return last }
        return ChatScrollAnimation.bottomAnchor
    }

    private func markInitialBottomScrollComplete() {
        hasCompletedInitialBottomScroll = true
        initialOpenBottomScrollPending = false
        lastAnchoredMessageClientId = viewModel.messages.last?.clientMessageId
    }

    private func handleListPanChanged(globalStart: CGPoint, localStart: CGPoint, listWidth: CGFloat, translation: CGSize) {
        let horizontal = translation.width
        let vertical = abs(translation.height)

        switch listPanSession {
        case .scrolling:
            return
        case .undecided:
            // Wait until axis is clear; do not claim vertical pans (ScrollView owns them).
            guard abs(horizontal) > 8 || vertical > 8 else { return }
            if vertical >= abs(horizontal) * 1.4 {
                listPanSession = .scrolling
                return
            }
            guard abs(horizontal) > vertical * 0.85 else { return }

            // Leading edge: UIKit interactive pop owns this band — never classify list pans here.
            if localStart.x < Self.navigationBackEdgeWidth {
                return
            }

            // Reply only when the finger started on the bubble. Empty row space
            // (spacers, gaps) keeps the list-wide timestamp reveal.
            if let hit = messageHit(at: globalStart) {
                let inReplyDirection = allowsThreadInteraction && (
                    hit.isOutgoing
                        ? horizontal < -4
                        : horizontal > 4
                )
                if inReplyDirection {
                    listPanSession = .replySwiping(
                        messageId: hit.messageId,
                        isOutgoing: hit.isOutgoing
                    )
                    replySwipeMessageId = hit.messageId
                } else {
                    listPanSession = .revealingTimestamps
                }
            } else {
                listPanSession = .revealingTimestamps
            }
            hideKeyboard()
            onDismissKeyboard()
        case .revealingTimestamps, .replySwiping:
            break
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true

        switch listPanSession {
        case .revealingTimestamps:
            let signed = horizontal < 0 ? -abs(horizontal) : abs(horizontal)
            withTransaction(transaction) {
                timestampRevealTranslation = signed
            }
        case .replySwiping(_, let isOutgoing):
            // 1:1 with the finger; soft-stop after max so the icon slot never rubber-bands wildly.
            let raw: CGFloat = isOutgoing ? min(0, horizontal) : max(0, horizontal)
            let distance = abs(raw)
            let eased: CGFloat
            if distance <= Self.replySwipeMaxOffset {
                eased = distance
            } else {
                eased = Self.replySwipeMaxOffset + (distance - Self.replySwipeMaxOffset) * 0.28
            }
            let signed = eased * (raw < 0 ? -1 : 1)
            withTransaction(transaction) {
                replySwipeTranslation = signed
            }
        case .undecided, .scrolling:
            break
        }
    }

    private func handleListPanEnded(translation: CGSize) {
        let endedSession = listPanSession
        listPanSession = .undecided

        switch endedSession {
        case .revealingTimestamps:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) {
                timestampRevealTranslation = 0
            }
        case .replySwiping(let messageId, let isOutgoing):
            let horizontal = translation.width
            let vertical = abs(translation.height)
            let triggered = abs(horizontal) > vertical && (
                isOutgoing
                    ? horizontal <= -Self.replySwipeThreshold
                    : horizontal >= Self.replySwipeThreshold
            )
            if triggered,
               let item = messages.first(where: { $0.id == messageId }) {
                Self.replySwipeImpact.impactOccurred()
                beginReply(to: item)
            }
            let finishingId = messageId
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                replySwipeTranslation = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                if replySwipeMessageId == finishingId, abs(replySwipeTranslation) < 0.5 {
                    replySwipeMessageId = nil
                }
            }
        case .undecided, .scrolling:
            replySwipeMessageId = nil
            replySwipeTranslation = 0
        }
    }

    private struct MessageHit {
        let messageId: UUID
        let isOutgoing: Bool
    }

    private func messageHit(at globalPoint: CGPoint) -> MessageHit? {
        let visibleIds = Set(messages.map(\.id))
        let frames = MessageReactionAnchorStore.shared.liveFrames(visibleIds: visibleIds)
        let containing = frames.filter { _, frame in
            frame.insetBy(dx: -8, dy: -6).contains(globalPoint)
        }
        guard let tightest = containing.min(by: { lhs, rhs in
            lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
        }) else { return nil }
        guard let message = messages.first(where: { $0.id == tightest.id }),
              !GroupSystemNoticePayload.displaysAsSystemNotice(message)
        else { return nil }

        return MessageHit(
            messageId: tightest.id,
            isOutgoing: message.senderId == currentUserId
        )
    }

    private func reactionFocusContext(for item: DisplayMessage, globalFrame: CGRect) -> MessageReactionFocusContext {
        MessageReactionFocusContext(
            session: reactionFocusSession,
            messageId: item.message.id,
            isOutgoing: item.message.senderId == currentUserId,
            frame: globalFrame,
            displayMessage: item,
            currentUserId: currentUserId,
            senderAvatarURL: senderAvatarURL(for: item.message),
            senderAvatarName: senderDisplayName(item.message),
            showsSenderAvatar: item.message.senderId != currentUserId
                && (item.groupPosition == .standalone || item.groupPosition == .groupLast)
        )
    }

    private func openReactionFocus(for item: DisplayMessage) {
        guard !GroupSystemNoticePayload.displaysAsSystemNotice(item.message) else { return }
        if reactionFocus != nil {
            dismissReactionFocus(force: true)
        }
        guard let globalFrame = MessageReactionAnchorStore.shared.frame(for: item.message.id),
              globalFrame.width > 1,
              globalFrame.height > 1
        else { return }

        let session = UUID()
        reactionFocusSession = session
        reactionFocusDismissArmed = false
        Self.longPressImpact.impactOccurred()
        InteractionScrollLock.setLocked(true)
        onDismissKeyboard()
        hideKeyboard()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            reactionFocus = reactionFocusContext(for: item, globalFrame: globalFrame)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reactionFocusDismissArmDelay) {
            guard reactionFocusSession == session, reactionFocus != nil else { return }
            reactionFocusDismissArmed = true
        }
    }

    private func prefetchRecentThreadMedia() {
        let recent = messages.suffix(12)
        var stillURLs: [URL] = []
        var gifURLs: [URL] = []
        stillURLs.reserveCapacity(recent.count)
        gifURLs.reserveCapacity(recent.count)
        for message in recent {
            for attachment in message.imageAttachments {
                if attachment.url.isLikelyAnimatedImage {
                    gifURLs.append(attachment.url)
                } else {
                    stillURLs.append(attachment.thumbnailURL ?? attachment.url)
                }
            }
        }
        ImagePrefetching.prefetch(
            urls: stillURLs,
            thumbnailWidth: RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: 220)
        )
        ImagePrefetching.prefetch(urls: gifURLs, thumbnailWidth: nil)
    }

    private func beginReply(to message: ChatMessage) {
        guard allowsThreadInteraction, !message.recalled else { return }
        guard !GroupSystemNoticePayload.displaysAsSystemNotice(message) else { return }
        dismissReactionFocus(force: true)
        viewModel.beginReply(to: message, senderDisplayName: senderDisplayName(message))
        onRequestComposerFocus()
    }

    /// DM uses the conversation peer photo; group falls back to initials until member avatars are mapped.
    private func senderAvatarURL(for message: ChatMessage) -> URL? {
        guard message.senderId != currentUserId else { return nil }
        return peerAvatarURL
    }

    private func typingSenderAvatarURL(typerId: UUID?) -> URL? {
        guard let typerId, typerId != currentUserId else { return nil }
        return peerAvatarURL
    }

    private func typingSenderDisplayName(typerId: UUID?) -> String {
        guard let typerId else { return peerDisplayName }
        if let fromMessage = messages.last(where: { $0.senderId == typerId }) {
            return senderDisplayName(fromMessage)
        }
        let fromUser = userDisplayName(typerId)
        return fromUser.isEmpty ? peerDisplayName : fromUser
    }

    private func dismissReactionFocus(force: Bool) {
        guard reactionFocus != nil else { return }
        guard force || reactionFocusDismissArmed else { return }
        reactionFocus = nil
        reactionFocusDismissArmed = false
        InteractionScrollLock.forceUnlock()
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard viewModel.messages.last != nil else { return }

        let target = resolvedBottomScrollTarget() ?? AnyHashable(ChatScrollAnimation.bottomAnchor)

        let performScroll = {
            if let lastId = self.viewModel.messages.last?.clientMessageId {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
            proxy.scrollTo(target, anchor: .bottom)
        }

        if animated {
            withAnimation(ChatScrollAnimation.spring) {
                performScroll()
            }
        } else {
            performScroll()
        }
    }

    private func scrollToBottomUntilVisible(proxy: ScrollViewProxy, animated: Bool) async {
        let retryDelaysMs: [UInt64] = animated
            ? [0, 50, 120]
            : [0, 16, 48, 96, 160, 280, 450, 700, 1_000]
        for (index, delayMs) in retryDelaysMs.enumerated() {
            if delayMs > 0 {
                try? await Task.sleep(for: .milliseconds(delayMs))
            }
            if userReleasedInitialPin {
                markInitialBottomScrollComplete()
                return
            }
            if !initialOpenBottomScrollPending {
                return
            }
            scrollToBottom(proxy: proxy, animated: false)
            _ = index
        }
        if userReleasedInitialPin {
            return
        }
        scrollToBottom(proxy: proxy, animated: false)
    }

    private func scrollToMessage(_ messageId: UUID, proxy: ScrollViewProxy) {
        // Bubbles use clientMessageId as ScrollViewReader id (stable across optimistic→server replace).
        let scrollId = messages.first(where: { $0.id == messageId })?.clientMessageId ?? messageId
        withAnimation(ChatScrollAnimation.jumpToMessage) {
            proxy.scrollTo(scrollId, anchor: .center)
        }
    }
}

private struct ChatListRowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Horizontal reply / timestamp pan that never claims the leading interactive-pop strip.
private struct ChatListHorizontalPanInstaller: UIViewRepresentable {
    var isEnabled: Bool
    var edgeExclusionWidth: CGFloat
    var onChanged: (_ globalStart: CGPoint, _ localStart: CGPoint, _ listWidth: CGFloat, _ translation: CGSize) -> Void
    var onEnded: (CGSize) -> Void
    var onNearBottomChanged: ((Bool) -> Void)? = nil
    var onUserScrolledAwayFromBottom: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MarkerView {
        let view = MarkerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.attachHandler = { [weak coordinator = context.coordinator] marker in
            coordinator?.attach(from: marker)
        }
        return view
    }

    func updateUIView(_ uiView: MarkerView, context: Context) {
        context.coordinator.edgeExclusionWidth = edgeExclusionWidth
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onNearBottomChanged = onNearBottomChanged
        context.coordinator.onUserScrolledAwayFromBottom = onUserScrolledAwayFromBottom
        uiView.attachHandler = { [weak coordinator = context.coordinator] marker in
            coordinator?.attach(from: marker)
        }
        context.coordinator.attach(from: uiView)
    }

    static func dismantleUIView(_ uiView: MarkerView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class MarkerView: UIView {
        var attachHandler: ((UIView) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachHandler?(self)
        }

        // Do not re-attach from layoutSubviews — tall message threads lay out many times
        // and that re-entered scroll KVO → SwiftUI publish during updates.
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var edgeExclusionWidth: CGFloat = 1
        var isEnabled = true
        var onChanged: ((_ globalStart: CGPoint, _ localStart: CGPoint, _ listWidth: CGFloat, _ translation: CGSize) -> Void)?
        var onEnded: ((CGSize) -> Void)?
        var onNearBottomChanged: ((Bool) -> Void)?
        var onUserScrolledAwayFromBottom: (() -> Void)?

        private weak var hostScrollView: UIScrollView?
        private weak var navigationController: UINavigationController?
        private var startLocation: CGPoint = .zero
        private var startLocal: CGPoint = .zero
        private var offsetObservation: NSKeyValueObservation?
        private var contentSizeObservation: NSKeyValueObservation?
        private var contentSizeReportWorkItem: DispatchWorkItem?
        private var lastReportedNearBottom: Bool?
        private var lastContentOffsetY: CGFloat = .nan
        private lazy var pan: UIPanGestureRecognizer = {
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            return gesture
        }()

        func attach(from markerView: UIView) {
            guard markerView.window != nil, let scrollView = chatListScrollView(from: markerView) else { return }
            let nav = navigationController(from: scrollView)
            if hostScrollView === scrollView, pan.view === scrollView, navigationController === nav {
                return
            }
            detach()
            scrollView.addGestureRecognizer(pan)
            // Stock interactive-pop is disabled on chat; only a hairline strict edge pan
            // can go back. Content past that strip is reply / timestamp.
            scrollView.panGestureRecognizer.require(toFail: pan)
            hostScrollView = scrollView
            navigationController = nav
            observeScrollProximity(scrollView)
        }

        func detach() {
            if let view = pan.view {
                view.removeGestureRecognizer(pan)
            }
            offsetObservation?.invalidate()
            contentSizeObservation?.invalidate()
            contentSizeReportWorkItem?.cancel()
            offsetObservation = nil
            contentSizeObservation = nil
            contentSizeReportWorkItem = nil
            lastReportedNearBottom = nil
            lastContentOffsetY = .nan
            hostScrollView = nil
            navigationController = nil
        }

        private func observeScrollProximity(_ scrollView: UIScrollView) {
            let report = { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.reportNearBottom(from: scrollView)
            }
            // contentOffset covers user pans; contentSize alone used to fire during every
            // LazyVStack layout of tall messages and publish into SwiftUI mid-update.
            offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { _, _ in
                report()
            }
            contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                // Coalesce contentSize storms when long messages lay out.
                self?.scheduleContentSizeNearBottomReport()
            }
            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.reportNearBottom(from: scrollView)
            }
        }

        private func scheduleContentSizeNearBottomReport() {
            contentSizeReportWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let scrollView = self.hostScrollView else { return }
                self.reportNearBottom(from: scrollView)
            }
            contentSizeReportWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }

        private func reportNearBottom(from scrollView: UIScrollView) {
            // Distance from the visible bottom edge to the content bottom.
            let insetBottom = scrollView.adjustedContentInset.bottom
            let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height - insetBottom
            let distance = scrollView.contentSize.height - visibleBottom
            var near = distance < 72

            let offsetY = scrollView.contentOffset.y
            let offsetMoved = lastContentOffsetY.isNaN || abs(offsetY - lastContentOffsetY) > 1.5
            // New messages / typing grow contentSize without moving offset. Keep the pin so
            // auto-follow and typing scroll are not dropped before the list catches up.
            if !near, lastReportedNearBottom == true, !offsetMoved {
                near = true
            }
            lastContentOffsetY = offsetY

            guard lastReportedNearBottom != near else { return }
            lastReportedNearBottom = near
            let nearCallback = onNearBottomChanged
            let awayCallback = onUserScrolledAwayFromBottom
            let userIsScrolling = scrollView.isDragging || scrollView.isDecelerating
            DispatchQueue.main.async {
                if near {
                    nearCallback?(true)
                } else if userIsScrolling {
                    awayCallback?()
                }
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard isEnabled, let view = gesture.view else { return }
            let translation = gesture.translation(in: view)
            let size = CGSize(width: translation.x, height: translation.y)

            switch gesture.state {
            case .began:
                onChanged?(startLocation, startLocal, view.bounds.width, size)
            case .changed:
                onChanged?(startLocation, startLocal, view.bounds.width, size)
            case .ended, .cancelled, .failed:
                onEnded?(size)
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard isEnabled, let view = gestureRecognizer.view else { return false }
            let point = touch.location(in: view)
            let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            let inContentBand: Bool
            if rtl {
                inContentBand = point.x < view.bounds.width - edgeExclusionWidth
            } else {
                inContentBand = point.x > edgeExclusionWidth
            }
            guard inContentBand else { return false }
            startLocation = touch.location(in: nil)
            startLocal = point
            return true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else {
                return false
            }
            let translation = pan.translation(in: view)
            return abs(translation.x) > abs(translation.y) && abs(translation.x) > 8
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        private func navigationController(from view: UIView) -> UINavigationController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let nav = current as? UINavigationController {
                    return nav
                }
                if let vc = current as? UIViewController, let nav = vc.navigationController {
                    return nav
                }
                responder = current.next
            }
            return nil
        }

        private func chatListScrollView(from marker: UIView) -> UIScrollView? {
            var ancestor: UIView? = marker.superview
            while let current = ancestor {
                if let match = preferredScrollView(in: current, relativeTo: marker) {
                    return match
                }
                ancestor = current.superview
            }
            return nil
        }

        private func preferredScrollView(in root: UIView, relativeTo marker: UIView) -> UIScrollView? {
            var found: [UIScrollView] = []
            collectScrollViews(from: root, into: &found)
            guard !found.isEmpty else { return nil }

            let markerCenter = marker.convert(
                CGPoint(x: marker.bounds.midX, y: marker.bounds.midY),
                to: root
            )
            let containing = found.filter { scroll in
                scroll.convert(scroll.bounds, to: root).insetBy(dx: -12, dy: -12).contains(markerCenter)
            }
            let candidates = containing.isEmpty ? found : containing
            let vertical = candidates.filter { scroll in
                scroll.contentSize.width <= scroll.bounds.width + 24
            }
            let pool = vertical.isEmpty ? candidates : vertical
            return pool.min { lhs, rhs in
                lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
            }
        }

        private func collectScrollViews(from root: UIView, into found: inout [UIScrollView]) {
            if let scroll = root as? UIScrollView {
                found.append(scroll)
            }
            for child in root.subviews {
                collectScrollViews(from: child, into: &found)
            }
        }
    }
}

private struct ChatThreadScrollTargetLayoutModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollTargetLayout()
        } else {
            content
        }
    }
}

private struct ChatThreadScrollPositionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            // defaultScrollAnchor only — scrollPosition(id:) on an unmeasured tall cell
            // leaves the viewport blank until the user pans.
            content.defaultScrollAnchor(.bottom)
        } else {
            content
        }
    }
}
