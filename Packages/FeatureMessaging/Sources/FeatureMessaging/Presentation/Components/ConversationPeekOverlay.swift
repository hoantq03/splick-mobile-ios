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
    /// Measured options chrome; initial guess matches a 2-column chip row.
    @State private var optionsSize = CGSize(width: 320, height: 48)
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
    /// Options band soft-cap as a fraction of the usable vertical space (keeps preview roomy on SE).
    private let optionsMaxHeightFraction: CGFloat = 0.22
    /// Preview always keeps at least this fraction of usable height.
    private let previewMinHeightFraction: CGFloat = 0.55

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
            // Morph from the list row into the stacked peek card — this is the bounce users expect.
            let currentFrame = isRevealed ? destFrame : context.anchorFrame
            let matchingRadius = max(
                Self.displayCornerRadius - edgeMargin,
                SplickTheme.CornerRadius.card
            )
            let previewShape = UnevenRoundedRectangle(
                topLeadingRadius: SplickTheme.CornerRadius.card,
                bottomLeadingRadius: matchingRadius,
                bottomTrailingRadius: matchingRadius,
                topTrailingRadius: SplickTheme.CornerRadius.card,
                style: .continuous
            )

            ZStack(alignment: .topLeading) {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard dismissIsArmed else { return }
                        dismissAnimated(completion: onDismiss)
                    }

                optionsStack(maxWidth: layout.optionsFrame.width)
                    .frame(width: layout.optionsFrame.width, alignment: .leading)
                    .background(optionsSizeReader)
                    .onPreferenceChange(PeekOptionsSizeKey.self) { size in
                        guard size.width > 1, size.height > 1, !didFreezeOptionsSize else { return }
                        didFreezeOptionsSize = true
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            optionsSize = size
                        }
                    }
                    .scaleEffect(
                        isOptionsRevealed ? 1 : 0.72,
                        anchor: .top
                    )
                    .opacity(isOptionsRevealed ? 1 : 0)
                    .offset(y: isOptionsRevealed ? 0 : -16)
                    .allowsHitTesting(isOptionsRevealed)
                    .position(
                        x: layout.optionsFrame.midX,
                        y: layout.optionsFrame.midY
                    )
                    .compositingGroup()
                    .zIndex(2)
            }
            .overlay {
                previewCard(shape: previewShape)
                    .frame(width: currentFrame.width, height: currentFrame.height)
                    .clipShape(previewShape)
                    .compositingGroup()
                    .scaleEffect(isRevealed ? 1 : 0.96, anchor: .top)
                    .position(x: currentFrame.midX, y: currentFrame.midY)
                    .animation(ConversationPeekMotion.appear, value: isRevealed)
                    .zIndex(1)
                    .onTapGesture {
                        guard dismissIsArmed else { return }
                        dismissAnimated(completion: onOpen)
                    }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Paint the first frame at the list-row anchor, then spring-morph open.
            // Without the async hop, SwiftUI often skips the anchor frame and the bounce vanishes.
            isRevealed = false
            isOptionsRevealed = false
            DispatchQueue.main.async {
                withAnimation(ConversationPeekMotion.appear) {
                    isRevealed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + MessageReactionTrayMotion.optionsChromeDelay) {
                    withAnimation(ConversationPeekMotion.appear) {
                        isOptionsRevealed = true
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissArmDelay) {
                dismissIsArmed = true
            }
        }
        .transaction { transaction in
            if !isDismissing {
                transaction.disablesAnimations = false
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

    /// Two-column chip grid — short vertically, wraps to a second row if more actions appear.
    private func optionsStack(maxWidth: CGFloat) -> some View {
        let columns = [
            GridItem(.flexible(minimum: 96), spacing: SplickTheme.Spacing.xs),
            GridItem(.flexible(minimum: 96), spacing: SplickTheme.Spacing.xs),
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            optionChip(
                titleKey: .messagingChatDeleteConversation,
                systemImage: "trash",
                destructive: true,
                action: onDelete
            )
            optionChip(
                titleKey: context.conversation.notificationsEnabled
                    ? .messagingChatMuteNotifications
                    : .messagingChatUnmuteNotifications,
                systemImage: context.conversation.notificationsEnabled ? "bell.slash" : "bell",
                destructive: false,
                action: onMute
            )
            .animation(ConversationPeekMotion.muteToggle, value: context.conversation.notificationsEnabled)
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
    }

    private func optionChip(
        titleKey: L10nKey,
        systemImage: String,
        destructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(languageService.text(titleKey))
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(destructive ? SplickTheme.Colors.error : SplickTheme.Colors.textPrimary)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background {
            Capsule(style: .continuous)
                .fill(SplickTheme.Colors.cardBackground)
        }
        .contentShape(Capsule())
        .onTapGesture {
            Self.actionImpact.impactOccurred()
            action()
        }
    }

    private func previewCard(shape: UnevenRoundedRectangle) -> some View {
        VStack(spacing: 0) {
            ConversationRowView(
                conversation: context.conversation,
                reportsAnchorFrame: false,
                inboxTyping: inboxTyping
            )
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .animation(ConversationPeekMotion.muteToggle, value: context.conversation.notificationsEnabled)

            Divider()

            previewBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            shape
                .fill(SplickTheme.Colors.secondaryBackground)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .contentShape(shape)
    }

    @ViewBuilder
    private var previewBody: some View {
        switch loadState {
        case .idle, .loading:
            VStack(spacing: SplickTheme.Spacing.sm) {
                ProgressView()
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
                let rowWidth = max(geo.size.width - SplickTheme.Spacing.md * 2, 1)
                let bubbleMax = MessageThreadRowLayout.contentMaxWidth(forRowWidth: rowWidth)
                let displayMessages = MessageTimelineGrouping.buildDisplayMessages(from: messages)
                let bottomPinKey = messages.last?.clientMessageId
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        // VStack (not Lazy): peek pages are small; eager layout makes
                        // bottom-pin + prepend offset preservation reliable.
                        VStack(spacing: SplickTheme.Spacing.xxs) {
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
                                    ProgressView()
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
                        .padding(SplickTheme.Spacing.md)
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
        return HStack {
            if isOutgoing {
                Spacer(minLength: 44)
            }

            MessageBubble(
                displayMessage: item,
                isOutgoing: isOutgoing,
                currentUserId: context.currentUserId,
                presentation: .reactionFocusLift,
                focusMaxContentWidth: contentMaxWidth,
                contentMaxWidth: contentMaxWidth,
                onReact: { _ in },
                onRetry: nil,
                onLongPress: nil,
                onReply: nil
            )

            if !isOutgoing {
                Spacer(minLength: 44)
            }
        }
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

    /// Percentage-based stack: options on top (no overlap), preview fills the rest.
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
        let usableHeight = max(bottom - chromeTop, 200)

        // Prefer measured chip height; soft-cap only so SE still leaves a usable preview.
        let optionsHeightCap = usableHeight * optionsMaxHeightFraction
        let optionsHeight = min(max(optionsSize.height, 44), max(optionsHeightCap, 44))
        let optionsFrame = CGRect(
            x: left,
            y: chromeTop,
            width: width,
            height: optionsHeight
        )

        // Hard gap under options — never overlap (previous 55% pull-up covered the chips).
        let previewTop = optionsFrame.maxY + contentGap
        let previewMinHeight = usableHeight * previewMinHeightFraction
        let previewHeight = max(bottom - previewTop, min(previewMinHeight, usableHeight * 0.5))
        let previewFrame = CGRect(
            x: left,
            y: previewTop,
            width: width,
            height: previewHeight
        )

        return PeekLayout(optionsFrame: optionsFrame, previewFrame: previewFrame)
    }

    private static var displayCornerRadius: CGFloat {
        let screen = UIScreen.main
        if let radius = screen.value(forKey: "_displayCornerRadius") as? CGFloat, radius > 0 {
            return radius
        }
        if let radius = screen.value(forKey: "displayCornerRadius") as? CGFloat, radius > 0 {
            return radius
        }
        return SplickTheme.CornerRadius.extraLarge
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
        withAnimation(ConversationPeekMotion.dismiss) {
            isRevealed = false
            isOptionsRevealed = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ConversationPeekMotion.dismissSettlingDelay) {
            completion()
        }
    }
}

private enum ConversationPeekMotion {
    /// Morph from the list row with a soft overshoot (bounce).
    static let appear = Animation.spring(response: 0.42, dampingFraction: 0.58)
    /// Return to the list row without oscillating past it.
    static let dismiss = Animation.spring(response: 0.30, dampingFraction: 0.86)
    /// Mute bell / chip label while peek stays open.
    static let muteToggle = Animation.spring(response: 0.34, dampingFraction: 0.72)
    static let dismissSettlingDelay: TimeInterval = 0.28
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
    static var defaultValue: CGSize = CGSize(width: 320, height: 48)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1, next.height < 400 {
            value = next
        }
    }
}
