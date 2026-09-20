import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

struct ConversationPeekContext {
    let conversation: Conversation
    let anchorFrame: CGRect
    let currentUserId: UUID
}

struct ConversationPeekOverlay: View {
    @EnvironmentObject private var languageService: LanguageService

    let context: ConversationPeekContext
    let messages: [ChatMessage]
    let loadState: ConversationListViewModel.PeekLoadState
    var inboxTyping: InboxTypingState? = nil
    var hasMoreMessages = false
    var isLoadingOlder = false
    var prependAnchorMessageId: UUID? = nil
    let onDismiss: () -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onMute: () -> Void
    let onMarkRead: () -> Void
    var onLoadOlder: ((ChatMessage) -> Void)? = nil
    var onClearPrependAnchor: (() -> Void)? = nil

    @State private var isRevealed = false
    @State private var isOptionsRevealed = false
    @State private var isDismissing = false
    @State private var dismissIsArmed = false
    /// Initial open must land on the newest message; load-older waits until this is done.
    @State private var didCompleteInitialBottomPin = false
    /// User scrolled away from the newest edge — prepend must preserve mid-thread position.
    @State private var userReleasedBottomPin = false
    @State private var isNearTop = false
    /// Measured options chrome; initial guess for first frame before flow layout measures.
    @State private var optionsSize = CGSize(width: 320, height: 52)
    @State private var didFreezeOptionsSize = false
    private static let olderLoaderSlotHeight: CGFloat = 28
    private static let peekBottomAnchor = "peek-timeline-bottom"
    private static let initialBottomPinDelaysMs: [UInt64] = [0, 16, 48, 120]


    private static let dismissArmDelay: TimeInterval = 0.45
    private static let actionImpact = UIImpactFeedbackGenerator(style: .light)
    private let edgeMargin = SplickTheme.Spacing.md
    private let contentGap = SplickTheme.Spacing.sm
    /// Extra drop below the Dynamic Island / status bar so chips are fully visible.
    private let extraBelowIsland = SplickTheme.Spacing.sm
    /// Fallback band before the first real measure (≈ one chip row).
    private let optionsBandHeightFallback: CGFloat = 52

    var body: some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            let chromeTop = max(insets.top, Self.windowSafeAreaTop) + extraBelowIsland
            let layout = peekLayout(
                containerSize: geometry.size,
                insets: insets,
                chromeTop: chromeTop,
                optionsSize: optionsSize
            )
            let destFrame = layout.previewFrame
            // Morph from the list row into a floating peek card — inbox stays visible around it.
            let currentFrame = isRevealed ? destFrame : context.anchorFrame
            let previewShape = RoundedRectangle(
                cornerRadius: SplickTheme.CornerRadius.card,
                style: .continuous
            )

            ZStack(alignment: .topLeading) {
                Color.black
                    .opacity(isRevealed ? 0.45 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard dismissIsArmed else { return }
                        dismissAnimated(completion: onDismiss)
                    }

                previewCard(shape: previewShape)
                    .frame(width: currentFrame.width, height: currentFrame.height)
                    .clipShape(previewShape)
                    .compositingGroup()
                    .scaleEffect(isRevealed ? 1 : 0.96, anchor: .top)
                    .offset(x: currentFrame.minX, y: currentFrame.minY)
                    .animation(ConversationPeekMotion.appear, value: isRevealed)
                    .zIndex(1)
                    .onTapGesture {
                        guard dismissIsArmed else { return }
                        dismissAnimated(completion: onOpen)
                    }

                optionsStack(maxWidth: layout.optionsFrame.width)
                    .frame(width: layout.optionsFrame.width, alignment: .leading)
                    .background(optionsSizeReader)
                    .onPreferenceChange(PeekOptionsSizeKey.self) { size in
                        guard size.width > 1, size.height > 1 else { return }
                        // Keep updating when height grows (wrap / longer locale) so the
                        // preview always sits below the chips — never overlaps them.
                        if didFreezeOptionsSize,
                           size.height <= optionsSize.height + 0.5,
                           abs(size.width - optionsSize.width) <= 0.5 {
                            return
                        }
                        didFreezeOptionsSize = true
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            optionsSize = size
                        }
                    }
                    .offset(x: layout.optionsFrame.minX, y: layout.optionsFrame.minY)
                    .allowsHitTesting(isOptionsRevealed)
                    .zIndex(2)
            }
        }
        .ignoresSafeArea()
        .background {
            PeekStatusBarTapCatcher {
                guard dismissIsArmed else { return }
                dismissAnimated(completion: onDismiss)
            }
        }
        .background(Color.clear)
        .onAppear {
            // Paint the first frame at the list-row anchor, then spring-morph open.
            // Without the async hop, SwiftUI often skips the anchor frame and the bounce vanishes.
            isRevealed = false
            isOptionsRevealed = false
            DispatchQueue.main.async {
                withAnimation(ConversationPeekMotion.appear) {
                    isRevealed = true
                }
                // Preview bounce first; then chips cascade L→R, top→bottom.
                DispatchQueue.main.asyncAfter(deadline: .now() + ConversationPeekMotion.optionsStartDelay) {
                    withAnimation(ConversationPeekMotion.chipAppear) {
                        isOptionsRevealed = true
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissArmDelay) {
                dismissIsArmed = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(languageService.text(.messagingConversationPeekA11y))
    }

    private var optionsSizeReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: PeekOptionsSizeKey.self, value: proxy.size)
        }
    }

    /// Intrinsic-width chips that wrap onto new rows via `FlowLayout` (matches Android FlowRow).
    private func optionsStack(maxWidth: CGFloat) -> some View {
        FlowLayout(spacing: SplickTheme.Spacing.xs, lineSpacing: SplickTheme.Spacing.xs) {
            optionChip(
                index: 0,
                titleKey: context.conversation.isMuted()
                    ? .messagingChatUnmuteNotifications
                    : .messagingChatMuteNotifications,
                systemImage: context.conversation.isMuted() ? "bell" : "bell.slash",
                destructive: false,
                action: onMute
            )
            .animation(ConversationPeekMotion.muteToggle, value: context.conversation.isMuted())
            optionChip(
                index: 1,
                titleKey: .messagingChatMarkAsRead,
                systemImage: "checkmark.message",
                destructive: false,
                action: onMarkRead
            )
            optionChip(
                index: 2,
                titleKey: .messagingChatDeleteConversation,
                systemImage: "trash",
                destructive: true,
                action: onDelete
            )
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
    }

    private func optionChip(
        index: Int,
        titleKey: L10nKey,
        systemImage: String,
        destructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let appearDelay = Double(index) * ConversationPeekMotion.chipStagger
        let dismissDelay = Double(ConversationPeekMotion.optionChipCount - 1 - index)
            * ConversationPeekMotion.chipStagger
        return HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .id(systemImage)
                .transition(.scale(scale: 0.72).combined(with: .opacity))
            Text(languageService.text(titleKey))
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .id(titleKey)
                .transition(.opacity)
        }
        .animation(ConversationPeekMotion.muteToggle, value: systemImage)
        .foregroundStyle(destructive ? SplickTheme.Colors.error : SplickTheme.Colors.textPrimary)
        // Match Android PeekOptionChip padding (12 / 11).
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background {
            Capsule(style: .continuous)
                .fill(SplickTheme.Colors.cardBackground)
        }
        .fixedSize(horizontal: true, vertical: true)
        .contentShape(Capsule())
        .scaleEffect(
            isOptionsRevealed ? 1 : ConversationPeekMotion.chipHiddenScale,
            anchor: .bottom
        )
        .opacity(isOptionsRevealed ? 1 : 0)
        .offset(y: isOptionsRevealed ? 0 : ConversationPeekMotion.chipHiddenOffsetY)
        .animation(
            ConversationPeekMotion.chipAppear.delay(isOptionsRevealed ? appearDelay : dismissDelay),
            value: isOptionsRevealed
        )
        .onTapGesture {
            Self.actionImpact.impactOccurred()
            action()
        }
    }

    private func previewCard(shape: RoundedRectangle) -> some View {
        VStack(spacing: 0) {
            ConversationRowView(
                conversation: context.conversation,
                reportsAnchorFrame: false,
                inboxTyping: inboxTyping
            )
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .animation(ConversationPeekMotion.muteToggle, value: context.conversation.isMuted())

            Divider()

            previewBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            shape
                // Match ChatThread surface so incoming bubbles (secondaryBackground) stay visible.
                .fill(SplickTheme.Colors.background)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .contentShape(shape)
    }

    @ViewBuilder
    private var previewBody: some View {
        switch loadState {
        case .idle, .loading:
            VStack(spacing: SplickTheme.Spacing.sm) {
                SplickSpinner()
                Text(languageService.text(.messagingChatLoading))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded where messages.isEmpty:
            previewStatus(
                systemImage: "bubble.left",
                message: languageService.text(.messagingConversationPeekEmpty)
            )

        case .failed:
            previewStatus(
                systemImage: "wifi.exclamationmark",
                message: languageService.text(.messagingConversationPeekError)
            )

        case .loaded:
            GeometryReader { geo in
                let rowWidth = max(geo.size.width - MessageThreadRowLayout.listHorizontalPadding * 2, 1)
                let bubbleMax = MessageThreadRowLayout.contentMaxWidth(forRowWidth: rowWidth)
                let displayMessages = MessageTimelineGrouping.buildDisplayMessages(from: messages)
                let bottomPinKey = messages.last?.clientMessageId
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        // VStack (not Lazy): peek pages are small; eager layout makes
                        // bottom-pin + prepend offset preservation reliable.
                        VStack(spacing: 0) {
                            PeekTimelineScrollBridge(
                                isPrepending: isLoadingOlder || prependAnchorMessageId != nil,
                                shouldPreserveOffset: userReleasedBottomPin,
                                onNearTopChange: { nearTop in
                                    isNearTop = nearTop
                                    requestOlderIfNeeded(nearTop: nearTop)
                                },
                                onNearBottomChange: { nearBottom in
                                    guard didCompleteInitialBottomPin else { return }
                                    if nearBottom {
                                        if userReleasedBottomPin {
                                            userReleasedBottomPin = false
                                        }
                                    } else if !userReleasedBottomPin {
                                        userReleasedBottomPin = true
                                    }
                                }
                            )
                            .frame(width: 0, height: 0)

                            if hasMoreMessages || isLoadingOlder {
                                ZStack {
                                    SplickSpinner()
                                        .opacity(isLoadingOlder ? 1 : 0)
                                }
                                .frame(height: Self.olderLoaderSlotHeight)
                                .frame(maxWidth: .infinity)
                                .accessibilityHidden(!isLoadingOlder)
                            }

                            ForEach(displayMessages) { item in
                                VStack(spacing: 0) {
                                    if item.showsTimeSeparator {
                                        MessageTimeSeparatorLabel(date: item.message.createdAt)
                                    }
                                    previewBubble(item, contentMaxWidth: bubbleMax)
                                }
                                .id(item.id)
                            }

                            Color.clear
                                .frame(height: 1)
                                .id(Self.peekBottomAnchor)
                        }
                        .padding(.horizontal, MessageThreadRowLayout.listHorizontalPadding)
                        .padding(.vertical, SplickTheme.Spacing.sm)
                        .transaction { $0.animation = nil }
                    }
                    .overlay(alignment: .bottom) {
                        JumpToLatestChip(
                            visible: userReleasedBottomPin && didCompleteInitialBottomPin,
                            onTap: { jumpPeekToNewest(proxy: proxy) }
                        )
                        .padding(.bottom, SplickTheme.Spacing.sm)
                    }
                    .task(id: bottomPinKey) {
                        await pinPeekToNewestIfNeeded(
                            lastMessageId: bottomPinKey,
                            proxy: proxy
                        )
                    }
                    .onChange(of: prependAnchorMessageId) { anchorId in
                        guard let anchorId else { return }
                        if userReleasedBottomPin {
                            // UIKit bridge already compensated contentOffset; only clear the flag.
                            DispatchQueue.main.async {
                                onClearPrependAnchor?()
                            }
                        } else {
                            // Still opening / parked on newest — keep showing the latest edge.
                            pinPeekToNewest(proxy: proxy)
                            DispatchQueue.main.async {
                                pinPeekToNewest(proxy: proxy)
                                onClearPrependAnchor?()
                            }
                        }
                        _ = anchorId
                    }
                    .onChange(of: isNearTop) { nearTop in
                        requestOlderIfNeeded(nearTop: nearTop)
                    }
                }
            }
        }
    }

    private func requestOlderIfNeeded(nearTop: Bool) {
        guard didCompleteInitialBottomPin, nearTop, hasMoreMessages, !isLoadingOlder else { return }
        guard let oldest = messages.first else { return }
        onLoadOlder?(oldest)
    }

    private func pinPeekToNewestIfNeeded(lastMessageId: UUID?, proxy: ScrollViewProxy) async {
        guard let lastMessageId, !messages.isEmpty else { return }
        if didCompleteInitialBottomPin, userReleasedBottomPin { return }

        for (index, delayMs) in Self.initialBottomPinDelaysMs.enumerated() {
            if delayMs > 0 {
                try? await Task.sleep(for: .milliseconds(delayMs))
            }
            if userReleasedBottomPin { return }
            pinPeekToNewest(proxy: proxy, lastMessageId: lastMessageId)
            if index == Self.initialBottomPinDelaysMs.count - 1 {
                didCompleteInitialBottomPin = true
            }
        }
    }

    private func pinPeekToNewest(proxy: ScrollViewProxy, lastMessageId: UUID? = nil) {
        let lastId = lastMessageId ?? messages.last?.clientMessageId
        pinPeekScroll(to: Self.peekBottomAnchor, anchor: .bottom, proxy: proxy)
        if let lastId {
            pinPeekScroll(to: lastId, anchor: .bottom, proxy: proxy)
        }
    }

    private func jumpPeekToNewest(proxy: ScrollViewProxy) {
        userReleasedBottomPin = false
        withAnimation(ChatScrollAnimation.spring) {
            proxy.scrollTo(Self.peekBottomAnchor, anchor: .bottom)
            if let lastId = messages.last?.clientMessageId {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private func pinPeekScroll(to id: some Hashable, anchor: UnitPoint, proxy: ScrollViewProxy) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(id, anchor: anchor)
        }
    }

    @ViewBuilder
    private func previewBubble(_ item: DisplayMessage, contentMaxWidth: CGFloat) -> some View {
        if GroupSystemNoticePayload.displaysAsSystemNotice(item.message) {
            GroupSystemNoticeLabel(
                text: GroupSystemNoticeCopy.text(
                    message: item.message,
                    currentUserId: context.currentUserId,
                    actorName: item.message.senderDisplayName,
                    languageService: languageService
                )
            )
        } else {
            previewUserBubble(item, contentMaxWidth: contentMaxWidth)
        }
    }

    private func previewUserBubble(_ item: DisplayMessage, contentMaxWidth: CGFloat) -> some View {
        let isOutgoing = item.message.senderId == context.currentUserId
        let peer = context.conversation.peer
        return MessageBubble(
            displayMessage: item,
            isOutgoing: isOutgoing,
            currentUserId: context.currentUserId,
            presentation: .threadRow,
            contentMaxWidth: contentMaxWidth,
            onReact: { _ in },
            onRetry: nil,
            onLongPress: nil,
            onReply: nil,
            senderAvatarURL: {
                guard !isOutgoing, let raw = peer?.avatarUrl, let url = URL(string: raw) else {
                    return nil
                }
                return url
            }(),
            senderAvatarName: item.message.senderDisplayName
                ?? peer?.displayTitle
                ?? ""
        )
    }

    private func previewStatus(systemImage: String, message: String) -> some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            Text(message)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(SplickTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private struct PeekLayout {
        let optionsFrame: CGRect
        let previewFrame: CGRect
    }

    /// Options on top; preview fills from below the chips down to tab-bar clearance.
    private func peekLayout(
        containerSize: CGSize,
        insets: EdgeInsets,
        chromeTop: CGFloat,
        optionsSize: CGSize
    ) -> PeekLayout {
        let left = insets.leading + edgeMargin
        let right = containerSize.width - insets.trailing - edgeMargin
        let bottom = containerSize.height - max(insets.bottom, Self.windowSafeAreaBottom)
            - SplickTabBarMetrics.floatingClearance - edgeMargin
        let width = max(right - left, 160)
        let optionsHeight = max(optionsSize.height, optionsBandHeightFallback)
        let optionsFrame = CGRect(
            x: left,
            y: chromeTop,
            width: width,
            height: optionsHeight
        )
        let previewRect = ConversationPeekLayout.previewDestination(
            top: chromeTop,
            bottom: bottom,
            optionsHeight: optionsHeight,
            gap: contentGap
        )
        let previewFrame = CGRect(
            x: left,
            y: previewRect.minY,
            width: width,
            height: previewRect.height
        )

        return PeekLayout(optionsFrame: optionsFrame, previewFrame: previewFrame)
    }

    private static var windowSafeAreaTop: CGFloat {
        windowSafeAreaInsets.top
    }

    private static var windowSafeAreaBottom: CGFloat {
        windowSafeAreaInsets.bottom
    }

    private static var windowSafeAreaInsets: UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        return window?.safeAreaInsets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    }

    private func dismissAnimated(completion: @escaping () -> Void) {
        guard !isDismissing else { return }
        isDismissing = true
        // Options reverse-cascade first (R→L / bottom→top), then preview settles.
        withAnimation(ConversationPeekMotion.chipAppear) {
            isOptionsRevealed = false
        }
        let previewDelay = ConversationPeekMotion.optionsDismissLeadIn
        DispatchQueue.main.asyncAfter(deadline: .now() + previewDelay) {
            withAnimation(ConversationPeekMotion.dismiss) {
                isRevealed = false
            }
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + previewDelay + ConversationPeekMotion.dismissSettlingDelay
        ) {
            completion()
        }
    }
}

enum ConversationPeekLayout {
    static let minPreviewHeight: CGFloat = 120

    /// Preview card starts below the action chips and fills down to [bottom]
    /// (already clears the floating tab bar) — matches Android peek layout.
    static func previewDestination(
        top: CGFloat,
        bottom: CGFloat,
        optionsHeight: CGFloat,
        gap: CGFloat
    ) -> CGRect {
        let previewTop = min(top + optionsHeight + gap, bottom - minPreviewHeight)
        let previewBottom = max(bottom, previewTop)
        return CGRect(x: 0, y: previewTop, width: 0, height: previewBottom - previewTop)
    }
}

private enum ConversationPeekMotion {
    /// Morph from the list row — snappy bounce.
    static let appear = Animation.spring(response: 0.30, dampingFraction: 0.56)
    /// Per-chip: scale up from small + overshoot bounce (appear and reverse dismiss).
    static let chipAppear = Animation.spring(response: 0.28, dampingFraction: 0.48)
    /// Wait for the preview spring to crest before cascading chips.
    static let optionsStartDelay: TimeInterval = 0.20
    /// Left→right / top→bottom cascade between chips (reverse on dismiss).
    static let chipStagger: TimeInterval = 0.040
    static let optionChipCount = 3
    /// Let the reverse chip cascade lead before the preview morphs away.
    static var optionsDismissLeadIn: TimeInterval {
        Double(optionChipCount - 1) * chipStagger + 0.08
    }
    /// Hidden chip starts smaller so the pop reads clearly.
    static let chipHiddenScale: CGFloat = 0.48
    static let chipHiddenOffsetY: CGFloat = 18
    /// Return to the list row without oscillating past it.
    static let dismiss = Animation.spring(response: 0.28, dampingFraction: 0.86)
    /// Mute bell / chip label while peek stays open.
    static let muteToggle = Animation.spring(response: 0.34, dampingFraction: 0.72)
    static let dismissSettlingDelay: TimeInterval = 0.26
}

/// Hosted inside the peek timeline so we can find the parent UIScrollView and:
/// 1) report near-top / near-bottom, 2) preserve offset while older pages prepend.
private struct PeekTimelineScrollBridge: UIViewRepresentable {
    var isPrepending: Bool
    var shouldPreserveOffset: Bool
    var onNearTopChange: (Bool) -> Void
    var onNearBottomChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onNearTopChange: onNearTopChange, onNearBottomChange: onNearBottomChange)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onNearTopChange = onNearTopChange
        context.coordinator.onNearBottomChange = onNearBottomChange
        context.coordinator.isPrepending = isPrepending
        context.coordinator.shouldPreserveOffset = shouldPreserveOffset
        if isPrepending, shouldPreserveOffset {
            context.coordinator.armPrependWindow()
        }
        context.coordinator.attachIfNeeded(from: uiView)
    }

    final class Coordinator {
        var onNearTopChange: (Bool) -> Void
        var onNearBottomChange: (Bool) -> Void
        var isPrepending = false
        var shouldPreserveOffset = false
        private weak var scrollView: UIScrollView?
        private var offsetObservation: NSKeyValueObservation?
        private var sizeObservation: NSKeyValueObservation?
        private var lastContentHeight: CGFloat = 0
        private var lastNearTop = false
        private var lastNearBottom = true
        private var prependUntil: CFTimeInterval = 0

        init(
            onNearTopChange: @escaping (Bool) -> Void,
            onNearBottomChange: @escaping (Bool) -> Void
        ) {
            self.onNearTopChange = onNearTopChange
            self.onNearBottomChange = onNearBottomChange
        }

        func armPrependWindow() {
            prependUntil = CACurrentMediaTime() + 0.4
        }

        func attachIfNeeded(from view: UIView) {
            guard scrollView == nil else { return }
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view, self.scrollView == nil else { return }
                guard let scroll = Self.findScrollView(from: view) else { return }
                self.scrollView = scroll
                self.lastContentHeight = scroll.contentSize.height
                self.observe(scroll)
                self.reportProximity(from: scroll)
            }
        }

        private func observe(_ scroll: UIScrollView) {
            offsetObservation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
                self?.reportProximity(from: scroll)
            }
            sizeObservation = scroll.observe(\.contentSize, options: [.old, .new]) { [weak self] scroll, change in
                self?.handleContentSizeChange(scroll: scroll, change: change)
                self?.reportProximity(from: scroll)
            }
        }

        private func handleContentSizeChange(
            scroll: UIScrollView,
            change: NSKeyValueObservedChange<CGSize>
        ) {
            let oldHeight = change.oldValue?.height ?? lastContentHeight
            let newHeight = change.newValue?.height ?? scroll.contentSize.height
            let delta = newHeight - oldHeight
            lastContentHeight = newHeight
            guard delta > 0.5 else { return }
            let shouldPreserve = shouldPreserveOffset
                && (isPrepending || CACurrentMediaTime() < prependUntil)
            guard shouldPreserve else { return }
            var offset = scroll.contentOffset
            offset.y += delta
            let maxOffset = max(
                0,
                scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
            )
            offset.y = min(max(offset.y, -scroll.adjustedContentInset.top), maxOffset)
            scroll.setContentOffset(offset, animated: false)
        }

        private func reportProximity(from scroll: UIScrollView) {
            let insetTop = scroll.adjustedContentInset.top
            let insetBottom = scroll.adjustedContentInset.bottom
            let offsetY = scroll.contentOffset.y + insetTop
            let visibleBottom = scroll.contentOffset.y + scroll.bounds.height - insetBottom
            let distanceFromBottom = scroll.contentSize.height - visibleBottom
            let nearTop = offsetY <= 48
            let nearBottom = distanceFromBottom <= 48
            if nearTop != lastNearTop {
                lastNearTop = nearTop
                DispatchQueue.main.async { self.onNearTopChange(nearTop) }
            }
            if nearBottom != lastNearBottom {
                lastNearBottom = nearBottom
                DispatchQueue.main.async { self.onNearBottomChange(nearBottom) }
            }
        }

        private static func findScrollView(from view: UIView) -> UIScrollView? {
            var current: UIView? = view.superview
            while let node = current {
                if let scroll = node as? UIScrollView {
                    return scroll
                }
                current = node.superview
            }
            return nil
        }
    }
}

private struct PeekOptionsSizeKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 320, height: 104)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1, next.height < 400 {
            value = next
        }
    }
}

/// Clock / cellular / battery sit in a system window above SwiftUI. A thin
/// scene window at alert level covers that strip so peek can dismiss there.
private struct PeekStatusBarTapCatcher: UIViewRepresentable {
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        context.coordinator.hostView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.installIfNeeded()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        var onTap: () -> Void
        let hostView = UIView()
        private var overlayWindow: UIWindow?

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
            hostView.isUserInteractionEnabled = false
            hostView.backgroundColor = .clear
        }

        func installIfNeeded() {
            if overlayWindow != nil { return }
            let install = { [weak self] in
                guard let self, self.overlayWindow == nil else { return }
                guard let scene = self.hostView.window?.windowScene
                    ?? UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
                else { return }
                let window = UIWindow(windowScene: scene)
                window.windowLevel = .alert
                window.backgroundColor = .clear
                window.frame = Self.stripFrame(in: scene)
                let controller = PeekStatusBarTapController()
                controller.onTap = { [weak self] in self?.onTap() }
                window.rootViewController = controller
                window.isHidden = false
                self.overlayWindow = window
            }
            if hostView.window == nil {
                DispatchQueue.main.async(execute: install)
            } else {
                install()
            }
        }

        func teardown() {
            overlayWindow?.isHidden = true
            overlayWindow?.rootViewController = nil
            overlayWindow = nil
        }

        static func stripFrame(in scene: UIWindowScene) -> CGRect {
            let bounds = scene.coordinateSpace.bounds
            let statusHeight = scene.statusBarManager?.statusBarFrame.height ?? 0
            let safeTop = (scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first)?
                .safeAreaInsets.top ?? 0
            let height = max(statusHeight, safeTop, 54)
            return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: height)
        }
    }
}

private final class PeekStatusBarTapController: UIViewController {
    var onTap: () -> Void = {}

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = true
        view.addGestureRecognizer(tap)
        self.view = view
    }

    override var prefersStatusBarHidden: Bool { false }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard let scene = view.window?.windowScene else { return }
        view.window?.frame = PeekStatusBarTapCatcher.Coordinator.stripFrame(in: scene)
    }

    @objc private func handleTap() {
        onTap()
    }
}
