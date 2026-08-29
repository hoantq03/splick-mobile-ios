import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain

struct ChatMessageListView: View {
    @Environment(\.messagingReactionPicker) private var reactionPicker
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
    var isComposerFocused: Bool = false
    var bottomOverlayInset: CGFloat = 8
    var onOpenDetails: (ChatMessage) -> Void = { _ in }

    @State private var reactionFocusMessageId: UUID?
    /// Fresh identity each open so `@State isRevealed` cannot stick across odd/even mounts.
    @State private var reactionFocusSession = UUID()
    /// Snapshot at open — opacity-0 source bubble can stop publishing a usable frame.
    @State private var reactionFocusFrozenFrame: CGRect?
    /// Ignore drag / dim-tap dismiss until the long-press finger has lifted.
    @State private var reactionFocusDismissArmed = false
    @State private var timestampRevealTranslation: CGFloat = 0
    /// Driven from the list pan so bubble-local DragGesture cannot steal vertical scroll.
    @State private var replySwipeMessageId: UUID?
    @State private var replySwipeTranslation: CGFloat = 0
    /// Once a drag is classified (scroll / reply / timestamp), stick with it.
    @State private var listPanSession: ListPanSession = .undecided
    @State private var hasCompletedInitialBottomScroll = false
    @State private var initialOpenBottomScrollPending = true
    @State private var lastHandledScrollToBottomToken = 0
    @State private var lastAnchoredMessageClientId: UUID?
    @State private var bottomScrollPosition: AnyHashable?

    private static let longPressImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let replySwipeImpact = UIImpactFeedbackGenerator(style: .light)
    private static let reactionFocusDismissArmDelay: TimeInterval = 0.45
    private static let replySwipeThreshold: CGFloat = 56
    /// Past the icon slot (46) so threshold is reachable while reveal stays 1:1.
    private static let replySwipeMaxOffset: CGFloat = 72
    /// Leading screen edge reserved for UIKit interactive pop (swipe back).
    private static let navigationBackEdgeWidth: CGFloat = 44
    /// Band just inward from the edge — horizontal pans here reveal timestamps (not reply).
    private static let timestampEdgeBandWidth: CGFloat = 52

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

        ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.isLoadingOlder {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SplickTheme.Spacing.sm)
                        }

                        ForEach(displayMessages) { item in
                            VStack(spacing: 0) {
                                if item.showsTimeSeparator {
                                    MessageTimeSeparatorLabel(date: item.message.createdAt)
                                }

                                if item.message.isSystemNotice {
                                    GroupSystemNoticeLabel(
                                        text: GroupSystemNoticeCopy.text(
                                            message: item.message,
                                            currentUserId: currentUserId,
                                            actorName: userDisplayName(item.message.senderId),
                                            languageService: languageService
                                        )
                                    )
                                } else {
                                    MessageBubble(
                                        displayMessage: item,
                                        isOutgoing: item.message.senderId == currentUserId,
                                        currentUserId: currentUserId,
                                        isHighlighted: viewModel.highlightedMessageId == item.message.id,
                                        highlightPulseToken: viewModel.scrollToMessageToken,
                                        isFloatingSend: viewModel.newlySentMessageIds.contains(item.message.clientMessageId),
                                        floatSway: viewModel.floatSway(for: item.message.clientMessageId),
                                        timestampRevealTranslation: timestampRevealTranslation,
                                        replySwipeTranslation: replySwipeMessageId == item.message.id
                                            ? replySwipeTranslation
                                            : 0,
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
                                        },
                                        onQuotedReply: { originId in
                                            Task { await viewModel.revealSearchedMessage(id: originId) }
                                        },
                                        readReceiptPeerAvatarURL: peerAvatarURL,
                                        readReceiptPeerName: peerDisplayName,
                                        showsReadReceiptAvatar: showsPeerReadAvatar
                                            && item.message.id == latestReadOutgoingMessageId,
                                    )
                                    .opacity(reactionFocusMessageId == item.message.id ? 0 : 1)
                                    .allowsHitTesting(reactionFocusMessageId != item.message.id)
                                }
                            }
                            .id(item.message.clientMessageId)
                            .transition(
                                hasCompletedInitialBottomScroll
                                    ? ChatScrollAnimation.messageInsert
                                    : .identity
                            )
                            .onAppear {
                                guard item.message.id == messages.first?.id else { return }
                                Task { await viewModel.loadOlderMessagesIfNeeded(current: item.message) }
                            }
                        }

                        if !viewModel.typingUserIds.isEmpty {
                            MessageTypingIndicatorBubble()
                                .id("typing-indicator")
                                .transition(
                                    hasCompletedInitialBottomScroll
                                        ? ChatScrollAnimation.messageInsert
                                        : .identity
                                )
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(ChatScrollAnimation.bottomAnchor)
                            .onAppear {
                                viewModel.isNearBottom = true
                                if initialOpenBottomScrollPending {
                                    markInitialBottomScrollComplete()
                                } else {
                                    hasCompletedInitialBottomScroll = true
                                }
                            }
                            .onDisappear { viewModel.isNearBottom = false }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.top, SplickTheme.Spacing.sm)
                    .padding(.bottom, SplickTheme.Spacing.sm + bottomOverlayInset)
                    .frame(maxWidth: .infinity)
                    .modifier(ChatThreadScrollTargetLayoutModifier())
                    .onAppear { prefetchRecentThreadMedia() }
                    .onChange(of: messages.suffix(12).map(\.id)) { _ in
                        prefetchRecentThreadMedia()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .background {
                    ChatListHorizontalPanInstaller(
                        isEnabled: reactionFocusMessageId == nil,
                        edgeExclusionWidth: Self.navigationBackEdgeWidth,
                        onChanged: handleListPanChanged,
                        onEnded: handleListPanEnded
                    )
                }
                .modifier(
                    ChatThreadScrollPositionModifier(
                        scrollPosition: $bottomScrollPosition,
                        bindsScrollPosition: initialOpenBottomScrollPending
                    )
                )
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
                            onCopy: {
                                let body = focusContext.displayMessage.message.body
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !body.isEmpty else { return }
                                UIPasteboard.general.string = body
                            },
                            onDetails: {
                                let message = focusContext.displayMessage.message
                                dismissReactionFocus(force: true)
                                onOpenDetails(message)
                            },
                            onOpenFullPicker: {
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
            .overlayPreferenceValue(ChatReadReceiptAnchorKey.self) { anchor in
                ChatReadReceiptAvatarOverlay(
                    anchor: anchor,
                    avatarURL: peerAvatarURL,
                    avatarName: peerDisplayName,
                    isVisible: showsPeerReadAvatar && latestReadOutgoingMessageId != nil
                )
            }
            .onAppear {
                syncBottomScrollPosition()
                scrollToBottom(proxy: proxy, animated: false)
                revealThreadIfNeeded()
            }
            .task(id: bottomScrollTaskKey) {
                guard viewModel.scrollToMessageToken == 0 else { return }
                guard viewModel.highlightedMessageId == nil else { return }
                guard viewModel.prependAnchorMessageId == nil else { return }
                guard !viewModel.messages.isEmpty || !viewModel.typingUserIds.isEmpty else { return }

                let tokenIncreased = viewModel.scrollToBottomToken > lastHandledScrollToBottomToken
                let isInitial = !hasCompletedInitialBottomScroll || initialOpenBottomScrollPending
                if !isInitial,
                   !tokenIncreased,
                   !viewModel.isNearBottom,
                   viewModel.typingUserIds.isEmpty { return }

                if tokenIncreased {
                    lastHandledScrollToBottomToken = viewModel.scrollToBottomToken
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
                    if !viewModel.typingUserIds.isEmpty {
                        try? await Task.sleep(for: .milliseconds(40))
                        scrollToTypingIndicator(proxy: proxy, animated: false)
                    }
                }
            }
            .task(id: typingScrollTaskKey) {
                guard !viewModel.typingUserIds.isEmpty else { return }
                guard viewModel.scrollToMessageToken == 0 else { return }
                guard viewModel.highlightedMessageId == nil else { return }
                await scrollToTypingIndicatorUntilVisible(
                    proxy: proxy,
                    animated: hasCompletedInitialBottomScroll && !initialOpenBottomScrollPending
                )
            }
            .onChange(of: viewModel.messages.last?.clientMessageId) { newLast in
                guard initialOpenBottomScrollPending, let newLast else { return }
                guard newLast != lastAnchoredMessageClientId else { return }
                lastAnchoredMessageClientId = newLast
                syncBottomScrollPosition()
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
            .onChange(of: isComposerFocused) { focused in
                guard focused else { return }
                guard viewModel.scrollToMessageToken == 0 else { return }
                guard viewModel.highlightedMessageId == nil else { return }
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            ) { notification in
                guard viewModel.scrollToMessageToken == 0 else { return }
                guard viewModel.highlightedMessageId == nil else { return }
                guard isComposerFocused || viewModel.isNearBottom || initialOpenBottomScrollPending else { return }
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
                lastHandledScrollToBottomToken = 0
                lastAnchoredMessageClientId = nil
                bottomScrollPosition = nil
            }
            .onChange(of: viewModel.scrollToMessageToken) { token in
                guard token > 0, let targetId = viewModel.highlightedMessageId else { return }
                scrollToMessage(targetId, proxy: proxy)
            }
        }
    }

    private var typingScrollTaskKey: String {
        let ids = viewModel.typingUserIds.map(\.uuidString).sorted().joined(separator: ",")
        let last = viewModel.messages.last?.clientMessageId.uuidString ?? "none"
        return "\(conversationId?.uuidString ?? "none")-\(ids)-\(last)-\(viewModel.messages.count)"
    }

    private var bottomScrollTaskKey: String {
        let conversation = conversationId?.uuidString ?? "none"
        let last = viewModel.messages.last?.clientMessageId.uuidString ?? "none"
        let count = viewModel.messages.count
        return "\(conversation)-\(last)-\(count)-\(viewModel.scrollToBottomToken)-\(viewModel.typingUserIds.count)"
    }

    private func resolvedBottomScrollTarget() -> AnyHashable? {
        if !viewModel.typingUserIds.isEmpty { return "typing-indicator" }
        if let last = viewModel.messages.last?.clientMessageId { return last }
        return ChatScrollAnimation.bottomAnchor
    }

    private func syncBottomScrollPosition() {
        guard initialOpenBottomScrollPending else { return }
        bottomScrollPosition = resolvedBottomScrollTarget()
    }

    private func revealThreadIfNeeded() {
        if !hasCompletedInitialBottomScroll {
            hasCompletedInitialBottomScroll = true
        }
    }

    private func markInitialBottomScrollComplete() {
        hasCompletedInitialBottomScroll = true
        initialOpenBottomScrollPending = false
        lastAnchoredMessageClientId = viewModel.messages.last?.clientMessageId
    }

    private func handleListPanChanged(start: CGPoint, translation: CGSize) {
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
            if start.x < Self.navigationBackEdgeWidth {
                return
            }

            let inLeadingTimestampBand = start.x < Self.navigationBackEdgeWidth + Self.timestampEdgeBandWidth
            let screenWidth = UIScreen.main.bounds.width
            let inTrailingTimestampBand = start.x > screenWidth - Self.navigationBackEdgeWidth - Self.timestampEdgeBandWidth

            if let hit = messageHit(at: start) {
                let inReplyDirection = hit.isOutgoing
                    ? horizontal < -4
                    : horizontal > 4
                let inTimestampDirection = hit.isOutgoing
                    ? horizontal > 4
                    : horizontal < -4
                if inReplyDirection {
                    listPanSession = .replySwiping(
                        messageId: hit.messageId,
                        isOutgoing: hit.isOutgoing
                    )
                    replySwipeMessageId = hit.messageId
                } else if inTimestampDirection, inLeadingTimestampBand || inTrailingTimestampBand {
                    listPanSession = .revealingTimestamps
                } else {
                    return
                }
            } else if inLeadingTimestampBand || inTrailingTimestampBand {
                listPanSession = .revealingTimestamps
            } else {
                return
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
        guard !frames.isEmpty else { return nil }

        var best: (hit: MessageHit, distance: CGFloat)?

        for (id, frame) in frames {
            let distance: CGFloat
            if globalPoint.y >= frame.minY, globalPoint.y < frame.maxY {
                distance = abs(globalPoint.y - frame.midY) * 0.01
            } else if globalPoint.y < frame.minY {
                distance = frame.minY - globalPoint.y
            } else {
                distance = globalPoint.y - frame.maxY
            }
            // Ignore rows that are clearly not the finger's row (stale / far).
            guard distance < 80 else { continue }
            guard let message = messages.first(where: { $0.id == id }) else { continue }
            guard !message.isSystemNotice else { continue }

            let hit = MessageHit(
                messageId: id,
                isOutgoing: message.senderId == currentUserId
            )
            if let current = best {
                if distance < current.distance {
                    best = (hit, distance)
                }
            } else {
                best = (hit, distance)
            }
        }

        return best?.hit
    }

    private func reactionFocusContext(
        in displayMessages: [DisplayMessage],
        overlayOrigin: CGPoint
    ) -> MessageReactionFocusContext? {
        guard let messageId = reactionFocusMessageId,
              let globalFrame = reactionFocusFrozenFrame ?? MessageReactionAnchorStore.shared.frame(for: messageId),
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
        guard !item.message.isSystemNotice else { return }
        // Recover from a stuck focus id (overlay never mounted / never armed dismiss).
        if reactionFocusMessageId != nil {
            dismissReactionFocus(force: true)
        }
        guard let globalFrame = MessageReactionAnchorStore.shared.frame(for: item.message.id),
              globalFrame.width > 1,
              globalFrame.height > 1
        else { return }

        let session = UUID()
        reactionFocusSession = session
        reactionFocusFrozenFrame = globalFrame
        reactionFocusDismissArmed = false
        Self.longPressImpact.impactOccurred()
        InteractionScrollLock.setLocked(true)
        // Instant handoff to the overlay clone at the same frame — no fade/slide.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            reactionFocusMessageId = item.message.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reactionFocusDismissArmDelay) {
            guard reactionFocusSession == session, reactionFocusMessageId != nil else { return }
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
        guard !message.isSystemNotice else { return }
        dismissReactionFocus(force: true)
        viewModel.beginReply(to: message, senderDisplayName: senderDisplayName(message))
        onRequestComposerFocus()
    }

    private func dismissReactionFocus(force: Bool) {
        guard reactionFocusMessageId != nil else { return }
        guard force || reactionFocusDismissArmed else { return }
        // Overlay already sprang back to the anchor — clear focus without a second
        // layout animation that would slide the list bubble.
        reactionFocusMessageId = nil
        reactionFocusFrozenFrame = nil
        reactionFocusDismissArmed = false
        InteractionScrollLock.forceUnlock()
    }

    private func scrollToTypingIndicatorUntilVisible(proxy: ScrollViewProxy, animated: Bool) async {
        guard !viewModel.typingUserIds.isEmpty else { return }
        let retryDelaysMs: [UInt64] = [0, 16, 48, 96, 160, 280, 450]
        for (index, delayMs) in retryDelaysMs.enumerated() {
            if delayMs > 0 {
                try? await Task.sleep(for: .milliseconds(delayMs))
            }
            scrollToTypingIndicator(
                proxy: proxy,
                animated: animated && index == 0
            )
            if viewModel.isNearBottom { return }
        }
        scrollToTypingIndicator(proxy: proxy, animated: false)
    }

    private func scrollToTypingIndicator(proxy: ScrollViewProxy, animated: Bool) {
        guard !viewModel.typingUserIds.isEmpty else { return }

        let performScroll = {
            proxy.scrollTo("typing-indicator", anchor: .bottom)
            proxy.scrollTo(AnyHashable(ChatScrollAnimation.bottomAnchor), anchor: .bottom)
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
            : [0, 16, 48, 96, 160, 280]
        syncBottomScrollPosition()
        for (index, delayMs) in retryDelaysMs.enumerated() {
            if delayMs > 0 {
                try? await Task.sleep(for: .milliseconds(delayMs))
            }
            scrollToBottom(proxy: proxy, animated: false)
            if index == 0 {
                revealThreadIfNeeded()
            }
            if viewModel.isNearBottom {
                markInitialBottomScrollComplete()
                return
            }
        }
        // LazyVStack can miss the bottom anchor on the first pass — reveal anyway after
        // the last programmatic scroll so the thread is never stuck invisible.
        scrollToBottom(proxy: proxy, animated: false)
        markInitialBottomScrollComplete()
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let hasMessages = viewModel.messages.last != nil
        let hasTyping = !viewModel.typingUserIds.isEmpty
        guard hasMessages || hasTyping else { return }

        if hasTyping {
            scrollToTypingIndicator(proxy: proxy, animated: animated)
            return
        }

        syncBottomScrollPosition()
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

    private func scrollToMessage(_ messageId: UUID, proxy: ScrollViewProxy) {
        // Bubbles use clientMessageId as ScrollViewReader id (stable across optimistic→server replace).
        let scrollId = messages.first(where: { $0.id == messageId })?.clientMessageId ?? messageId
        withAnimation(ChatScrollAnimation.jumpToMessage) {
            proxy.scrollTo(scrollId, anchor: .center)
        }
    }
}

/// Horizontal reply / timestamp pan that never claims the leading interactive-pop strip.
private struct ChatListHorizontalPanInstaller: UIViewRepresentable {
    var isEnabled: Bool
    var edgeExclusionWidth: CGFloat
    var onChanged: (CGPoint, CGSize) -> Void
    var onEnded: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.edgeExclusionWidth = edgeExclusionWidth
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        DispatchQueue.main.async {
            context.coordinator.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var edgeExclusionWidth: CGFloat = 44
        var isEnabled = true
        var onChanged: ((CGPoint, CGSize) -> Void)?
        var onEnded: ((CGSize) -> Void)?

        private weak var hostScrollView: UIScrollView?
        private var startLocation: CGPoint = .zero
        private lazy var pan: UIPanGestureRecognizer = {
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            return gesture
        }()

        func attach(from markerView: UIView) {
            guard let scrollView = nearestScrollView(from: markerView) else { return }
            if hostScrollView === scrollView, pan.view === scrollView { return }
            detach()
            scrollView.addGestureRecognizer(pan)
            hostScrollView = scrollView
        }

        func detach() {
            if let view = pan.view {
                view.removeGestureRecognizer(pan)
            }
            hostScrollView = nil
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard isEnabled, let view = gesture.view else { return }
            let translation = gesture.translation(in: view)
            let size = CGSize(width: translation.x, height: translation.y)

            switch gesture.state {
            case .began:
                startLocation = gesture.location(in: nil)
                onChanged?(startLocation, size)
            case .changed:
                onChanged?(startLocation, size)
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
            if rtl {
                return point.x < view.bounds.width - edgeExclusionWidth
            }
            return point.x > edgeExclusionWidth
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else {
                return false
            }
            let translation = pan.translation(in: view)
            if translation == .zero {
                return true
            }
            return abs(translation.x) >= abs(translation.y)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer === hostScrollView?.panGestureRecognizer
        }

        private func nearestScrollView(from view: UIView) -> UIScrollView? {
            var node: UIView? = view.superview
            while let current = node {
                if let scroll = current as? UIScrollView {
                    return scroll
                }
                if let found = current.subviews.compactMap({ $0 as? UIScrollView }).first {
                    return found
                }
                node = current.superview
            }
            return nil
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
    @Binding var scrollPosition: AnyHashable?
    var bindsScrollPosition: Bool

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            if bindsScrollPosition {
                content
                    .defaultScrollAnchor(.bottom)
                    .scrollPosition(id: $scrollPosition, anchor: .bottom)
            } else {
                content
                    .defaultScrollAnchor(.bottom)
            }
        } else {
            content
        }
    }
}
