import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain

struct MessageBubble: View {
    @EnvironmentObject private var languageService: LanguageService

    enum Presentation {
        /// Full chat row with spacers, timestamps, and gestures.
        case threadRow
        /// Bubble-only clone shown above the reaction dim overlay.
        case reactionFocusLift
    }

    let displayMessage: DisplayMessage
    let isOutgoing: Bool
    let currentUserId: UUID
    var isHighlighted: Bool = false
    var highlightPulseToken: Int = 0
    var isFloatingSend: Bool = false
    var floatSway: CGFloat = 0
    var presentation: Presentation = .threadRow
    /// When lifting into reaction focus, cap bubble width so text reflows instead of overflowing.
    var focusMaxContentWidth: CGFloat? = nil
    /// Measured thread row width (inside list padding). Scales bubbles with the screen.
    var contentMaxWidth: CGFloat = MessageThreadRowLayout.mediaFallbackMaxWidth
    /// Shared list drag: negative (swipe left) reveals right/outgoing times;
    /// positive (swipe right) reveals left/incoming times.
    var timestampRevealTranslation: CGFloat = 0
    /// List-owned reply swipe (1:1) — reveals reply icon in the timestamp/status slot.
    var replySwipeTranslation: CGFloat = 0
    let onReact: (String) -> Void
    let onRetry: (() -> Void)?
    let onLongPress: (() -> Void)?
    let onReply: (() -> Void)?
    /// Jump to the quoted original in the thread.
    var onQuotedReply: ((UUID) -> Void)? = nil
    /// Peer avatar for the latest `.read` outgoing receipt (DIRECT).
    var readReceiptPeerAvatarURL: URL? = nil
    var readReceiptPeerName: String = ""
    var showsReadReceiptAvatar: Bool = false

    @State private var imageViewerRoute: AttachmentPreviewRoute?

    /// Same optical width as the time slot so reply/time swap in place.
    private static let accessorySlotWidth: CGFloat = MessageThreadRowLayout.accessorySlotWidth
    private static let replyIconSize: CGFloat = 16
    /// Fits `HH:mm` with caption + monospaced digits.
    private static let timestampLabelWidth: CGFloat = MessageThreadRowLayout.accessorySlotWidth
    /// Gap between the revealed time and the bubble (inside the slot so rest layout does not shift).
    private static let timestampBubbleGap: CGFloat = 6
    private static let mediaCornerRadius: CGFloat = SplickTheme.CornerRadius.medium
    private static let rowSideSpacer: CGFloat = MessageThreadRowLayout.rowSideSpacer

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var message: ChatMessage { displayMessage.message }
    private var imageAttachments: [MessageImageAttachment] { displayMessage.imageAttachments }

    private var resolvedContentMaxWidth: CGFloat {
        if presentation == .reactionFocusLift, let focusMaxContentWidth {
            return focusMaxContentWidth
        }
        return contentMaxWidth
    }

    /// 1:1 with finger travel; capped once the full time label is visible.
    /// Swipe left → outgoing (right); swipe right → incoming (left).
    private var revealedTimestampWidth: CGFloat {
        // Reply swipe owns the accessory slot on this row — hide time while replying.
        guard replySwipeTranslation == 0 else { return 0 }
        let dragged = isOutgoing
            ? max(-timestampRevealTranslation, 0)
            : max(timestampRevealTranslation, 0)
        return min(dragged, Self.timestampLabelWidth)
    }

    private var replyIconOpacity: Double {
        let travel = abs(replySwipeTranslation)
        guard travel >= 4 else { return 0 }
        return Double(min(travel / 22, 1))
    }

    private var formattedTimestamp: String {
        Self.timestampFormatter.string(from: message.createdAt)
    }

    var body: some View {
        switch presentation {
        case .reactionFocusLift:
            focusLiftedBubble
        case .threadRow:
            threadRow
        }
    }

    private var focusLiftedBubble: some View {
        bubbleCluster
            .frame(maxWidth: resolvedContentMaxWidth, alignment: isOutgoing ? .trailing : .leading)
            .fixedSize(horizontal: true, vertical: true)
    }

    private var threadRow: some View {
        HStack(alignment: .center, spacing: 0) {
            if isOutgoing {
                Spacer(minLength: Self.rowSideSpacer)
                    .allowsHitTesting(false)
            } else {
                incomingLeadingMeta
            }

            slidingBubbleContent
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: replySwipeTranslation)
                .overlay(alignment: isOutgoing ? .trailing : .leading) {
                    replyIconBadge
                }

            if isOutgoing {
                outgoingTrailingMeta
            } else {
                Spacer(minLength: Self.rowSideSpacer)
                    .allowsHitTesting(false)
            }
        }
        .padding(.top, topSpacing)
    }

    private var slidingBubbleContent: some View {
        HStack(alignment: .messageDeliveryStatus, spacing: MessageThreadRowLayout.statusBubbleGap) {
            bubbleCluster
            if isOutgoing, message.deliveryStatus != .failed {
                MessageStatusIndicator(
                    status: message.deliveryStatus,
                    showsReadAvatar: showsReadReceiptAvatar,
                    readAvatarURL: readReceiptPeerAvatarURL,
                    readAvatarName: readReceiptPeerName,
                    readReceiptMessageId: message.id
                )
                .alignmentGuide(.messageDeliveryStatus) { dimensions in
                    dimensions[VerticalAlignment.bottom]
                }
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var incomingLeadingMeta: some View {
        timestampRevealLabel
            .fixedSize(horizontal: true, vertical: true)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var outgoingTrailingMeta: some View {
        timestampRevealLabel
            .fixedSize(horizontal: true, vertical: true)
            .allowsHitTesting(false)
    }

    /// Stays in the original bubble gap while the bubble slides, then springs back.
    private var replyIconBadge: some View {
        Image(systemName: "arrowshape.turn.up.left.fill")
            .font(.system(size: Self.replyIconSize, weight: .semibold))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(width: Self.accessorySlotWidth, height: Self.accessorySlotWidth)
            .scaleEffect(replyIconOpacity == 0 ? 0.82 : min(0.86 + abs(replySwipeTranslation) / 160, 1.08))
            .opacity(replyIconOpacity)
            .accessibilityHidden(replyIconOpacity < 0.35)
            .allowsHitTesting(false)
    }

    /// Time stays tucked under the outer edge; width opens 1:1 with the finger.
    private var timestampRevealLabel: some View {
        Text(formattedTimestamp)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .monospacedDigit()
            .lineLimit(1)
            .padding(isOutgoing ? .leading : .trailing, Self.timestampBubbleGap)
            .frame(
                width: Self.timestampLabelWidth,
                alignment: isOutgoing ? .leading : .trailing
            )
            .frame(
                width: revealedTimestampWidth,
                alignment: isOutgoing ? .leading : .trailing
            )
            .clipped()
            .accessibilityHidden(revealedTimestampWidth < 8)
            .allowsHitTesting(false)
    }

    private static let reactionAccessoryHeight: CGFloat = 26
    /// Half the accessory sits below the bubble bottom edge, half overlaps the bubble.
    private static let reactionAccessoryOverlap: CGFloat = reactionAccessoryHeight / 2

    private var bubbleCluster: some View {
        ZStack(alignment: isOutgoing ? .trailing : .leading) {
            bubbleContent
                .frame(
                    minWidth: reactionStripMinWidth,
                    maxWidth: resolvedContentMaxWidth,
                    alignment: isOutgoing ? .trailing : .leading
                )
                .overlay(alignment: isOutgoing ? .bottomLeading : .bottomTrailing) {
                    if showsReactionAccessory {
                        MessageReactionStrip(
                            counts: message.reactionCountsInsideOut(isOutgoing: isOutgoing),
                            currentUserId: currentUserId,
                            reactions: message.reactions,
                            maxWidth: resolvedContentMaxWidth,
                            onReact: onReact,
                            onOverflowTap: onLongPress
                        )
                        .offset(y: Self.reactionAccessoryOverlap)
                    }
                }
                .padding(.bottom, showsReactionAccessory ? Self.reactionAccessoryOverlap : 0)
        }
        .simultaneousGesture(longPressGesture)
        .overlay {
            if presentation == .threadRow {
                MessageBubbleAnchorProbe(messageId: message.id)
                    .allowsHitTesting(false)
            }
        }
        .messageSendFloat(isActive: isFloatingSend && presentation == .threadRow, lateralSway: floatSway)
        .modifier(
            MessageHighlightBounceModifier(
                pulseToken: (isHighlighted && presentation == .threadRow)
                    ? highlightPulseToken
                    : 0
            )
        )
    }

    private var showsReactionAccessory: Bool {
        !message.reactions.isEmpty
    }

    /// Widen short bubbles enough to seat visible reaction pills (capped at content max).
    private var reactionStripMinWidth: CGFloat {
        guard showsReactionAccessory else { return 0 }
        let layout = MessageReactionStripLayout.fit(
            counts: message.reactionCountsInsideOut(isOutgoing: isOutgoing),
            maxWidth: resolvedContentMaxWidth
        )
        return min(layout.occupiedWidth, resolvedContentMaxWidth)
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .onEnded { _ in
                guard presentation == .threadRow, onLongPress != nil else { return }
                // Haptic is fired by the list when focus actually opens.
                onLongPress?()
            }
    }

    private var hasTextBody: Bool {
        !message.body.isEmpty
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            if !imageAttachments.isEmpty {
                if let preview = message.replyPreview {
                    mediaReplyPreview(preview)
                }
                messageMediaAttachments
                    .modifier(MessageDeliveryStatusAnchor(isActive: !hasTextBody))
            }

            if hasTextBody || (message.replyPreview != nil && imageAttachments.isEmpty) {
                textBubbleBody
                    .modifier(MessageDeliveryStatusAnchor(isActive: true))
            }
        }
        .overlay {
            if message.deliveryStatus == .failed {
                failedOverlay
            }
        }
        .contentShape(Rectangle())
        .modifier(FailedMessageRetryTap(isFailed: message.deliveryStatus == .failed, onRetry: onRetry))
        .fullScreenCover(item: $imageViewerRoute) { route in
            attachmentFullscreenPreview(at: route.index)
        }
    }

    private var quotedReplyTap: (() -> Void)? {
        guard presentation == .threadRow,
              let onQuotedReply,
              let preview = message.replyPreview else { return nil }
        return { onQuotedReply(preview.messageId) }
    }

    /// Quote sits above media, outside the colored text bubble, so it must not use
    /// outgoing white text (that is invisible on the chat background).
    private func mediaReplyPreview(_ preview: MessageReplyPreview) -> some View {
        MessageQuotedReplyView(
            preview: preview,
            isOutgoing: isOutgoing,
            usesBubbleTextColors: false,
            onTap: quotedReplyTap
        )
        .padding(.horizontal, SplickTheme.Spacing.xs)
        .padding(.vertical, SplickTheme.Spacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SplickTheme.Colors.secondaryBackground)
        }
    }

    private var textBubbleBody: some View {
        // Quote + text share one clipped bubble. ViewThatFits hugs short lines;
        // long text wraps at textWrapMaxWidth.
        let core = VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            if imageAttachments.isEmpty, let preview = message.replyPreview {
                MessageQuotedReplyView(
                    preview: preview,
                    isOutgoing: isOutgoing,
                    usesBubbleTextColors: true,
                    maxContentWidth: textWrapMaxWidth,
                    onTap: quotedReplyTap
                )
            }
            if hasTextBody {
                messageTextLabel(lineLimit: nil)
            }
        }

        return ViewThatFits(in: .horizontal) {
            core.fixedSize(horizontal: true, vertical: true)
            core
                .frame(maxWidth: textWrapMaxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: textWrapMaxWidth, alignment: .leading)
        .padding(.horizontal, SplickTheme.Spacing.sm + 2)
        .padding(.vertical, SplickTheme.Spacing.xs + 2)
        .frame(
            minWidth: textReactionMinWidth,
            maxWidth: resolvedContentMaxWidth,
            alignment: .leading
        )
        .background(bubbleBackground)
        .clipShape(bubbleShape)
    }

    /// Grow a short text bubble to seat reaction pills without exceeding wrap max.
    private var textReactionMinWidth: CGFloat? {
        guard showsReactionAccessory, imageAttachments.isEmpty else { return nil }
        let padded = reactionStripMinWidth
        guard padded > 0 else { return nil }
        return min(padded, resolvedContentMaxWidth)
    }

    /// Max width available for wrapped text (excluding horizontal bubble padding).
    private var textWrapMaxWidth: CGFloat {
        max(resolvedContentMaxWidth - (SplickTheme.Spacing.sm + 2) * 2, 80)
    }

    private func messageTextLabel(lineLimit: Int?) -> some View {
        Text(message.body)
            .font(SplickTheme.Typography.body)
            .foregroundStyle(isOutgoing ? .white : SplickTheme.Colors.textPrimary)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
    }

    @ViewBuilder
    private var messageMediaAttachments: some View {
        let mediaWidth = resolvedContentMaxWidth
        if imageAttachments.count == 1,
           let attachment = imageAttachments.first,
           attachment.url.isLikelyAnimatedImage {
            InlineGifAttachmentView(
                url: attachment.url,
                maxWidth: mediaWidth,
                cornerRadius: Self.mediaCornerRadius,
                showsLoadingPlaceholder: true
            )
            .frame(maxWidth: mediaWidth)
            .onTapGesture {
                imageViewerRoute = AttachmentPreviewRoute(index: 0)
            }
        } else {
            InlineAttachmentImageGrid(
                images: imageAttachments.map(\.inlinePreviewImage),
                maxWidth: mediaWidth,
                cornerRadius: Self.mediaCornerRadius,
                onTapImage: { index in
                    imageViewerRoute = AttachmentPreviewRoute(index: index)
                }
            )
        }
    }

    @ViewBuilder
    private func attachmentFullscreenPreview(at index: Int) -> some View {
        if imageAttachments.indices.contains(index) {
            RemoteImageFullscreenPreview(
                urls: imageAttachments.map(\.url),
                initialIndex: index,
                onDismiss: { imageViewerRoute = nil }
            )
        }
    }

    private var failedOverlay: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.15)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 120
            )

            Text(languageService.text(.messagingTapToRetry))
                .font(SplickTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.xs)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.mediaCornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isOutgoing {
            LinearGradient(
                colors: [SplickTheme.Colors.primaryGradientStart, SplickTheme.Colors.primaryGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(message.deliveryStatus == .failed ? 0.45 : 1)
        } else {
            LinearGradient(
                colors: [SplickTheme.Colors.secondaryBackground, SplickTheme.Colors.secondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private static let bubbleCornerRadius: CGFloat = 24

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.bubbleCornerRadius, style: .continuous)
    }

    private var topSpacing: CGFloat {
        switch displayMessage.groupPosition {
        case .standalone, .groupFirst:
            return SplickTheme.Spacing.sm
        case .groupMiddle, .groupLast:
            return 2
        }
    }
}

private struct FailedMessageRetryTap: ViewModifier {
    let isFailed: Bool
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        if isFailed, onRetry != nil {
            content.onTapGesture { onRetry?() }
        } else {
            content
        }
    }
}

private extension VerticalAlignment {
    struct MessageDeliveryStatusAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.bottom]
        }
    }

    static let messageDeliveryStatus = VerticalAlignment(MessageDeliveryStatusAlignment.self)
}

private struct MessageDeliveryStatusAnchor: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.alignmentGuide(.messageDeliveryStatus) { dimensions in
                dimensions[VerticalAlignment.bottom]
            }
        } else {
            content
        }
    }
}

private struct MessageReactionStripLayout {
    let visible: [(emoji: String, count: Int)]
    let overflowCount: Int
    let occupiedWidth: CGFloat

    private static let spacing: CGFloat = 4
    private static let emojiSize: CGFloat = 18
    private static let horizontalPadding: CGFloat = 10

    static func fit(
        counts: [(emoji: String, count: Int)],
        maxWidth: CGFloat
    ) -> MessageReactionStripLayout {
        guard !counts.isEmpty else {
            return MessageReactionStripLayout(visible: [], overflowCount: 0, occupiedWidth: 0)
        }

        var visible: [(emoji: String, count: Int)] = []
        for item in counts {
            let trial = visible + [item]
            let overflow = counts.count - trial.count
            let width = occupiedWidth(visible: trial, overflowCount: overflow)
            if width <= maxWidth {
                visible = trial
            } else {
                break
            }
        }

        // Always surface at least an overflow chip when nothing fits.
        if visible.isEmpty {
            let overflow = counts.count
            return MessageReactionStripLayout(
                visible: [],
                overflowCount: overflow,
                occupiedWidth: min(overflowChipWidth(overflow), maxWidth)
            )
        }

        let overflow = counts.count - visible.count
        return MessageReactionStripLayout(
            visible: visible,
            overflowCount: overflow,
            occupiedWidth: occupiedWidth(visible: visible, overflowCount: overflow)
        )
    }

    private static func occupiedWidth(
        visible: [(emoji: String, count: Int)],
        overflowCount: Int
    ) -> CGFloat {
        var width: CGFloat = 0
        for (index, item) in visible.enumerated() {
            if index > 0 { width += spacing }
            width += pillWidth(count: item.count)
        }
        if overflowCount > 0 {
            if !visible.isEmpty { width += spacing }
            width += overflowChipWidth(overflowCount)
        }
        return width
    }

    private static func pillWidth(count: Int) -> CGFloat {
        let countWidth: CGFloat = count > 1 ? 2 + CGFloat(String(count).count) * 7 : 0
        return emojiSize + countWidth + horizontalPadding
    }

    private static func overflowChipWidth(_ count: Int) -> CGFloat {
        // "+N" monospaced-ish digit estimate.
        horizontalPadding + 8 + CGFloat(String(count).count) * 7
    }
}

private struct MessageReactionStrip: View {
    let counts: [(emoji: String, count: Int)]
    let currentUserId: UUID
    let reactions: [Reaction]
    let maxWidth: CGFloat
    let onReact: (String) -> Void
    let onOverflowTap: (() -> Void)?

    @State private var bouncingEmoji: String?

    private static let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    private var layout: MessageReactionStripLayout {
        MessageReactionStripLayout.fit(counts: counts, maxWidth: maxWidth)
    }

    var body: some View {
        let layout = self.layout
        HStack(spacing: 4) {
            ForEach(layout.visible, id: \.emoji) { item in
                let userReacted = reactions.contains { $0.userId == currentUserId && $0.emoji == item.emoji }
                let isBouncing = bouncingEmoji == item.emoji

                Button {
                    commitReaction(emoji: item.emoji)
                } label: {
                    HStack(spacing: 2) {
                        EmojiView(value: item.emoji, size: 18)
                        if item.count > 1 {
                            Text("\(item.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background {
                        Capsule(style: .continuous)
                            .fill(SplickTheme.Colors.background)
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                userReacted
                                    ? SplickTheme.Colors.primaryGradientStart.opacity(0.55)
                                    : SplickTheme.Colors.divider,
                                lineWidth: 0.5
                            )
                    }
                    .reactionTapBounce(isActive: isBouncing)
                }
                .buttonStyle(.plain)
            }

            if layout.overflowCount > 0 {
                overflowChip(count: layout.overflowCount)
            }
        }
        .onAppear { Self.impactFeedback.prepare() }
    }

    @ViewBuilder
    private func overflowChip(count: Int) -> some View {
        let label = Text("+\(count)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .monospacedDigit()
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                Capsule(style: .continuous)
                    .fill(SplickTheme.Colors.background)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(SplickTheme.Colors.divider, lineWidth: 0.5)
            }

        if let onOverflowTap {
            Button(action: onOverflowTap) {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    private func commitReaction(emoji: String) {
        Self.impactFeedback.impactOccurred()
        Self.impactFeedback.prepare()
        bouncingEmoji = emoji
        DispatchQueue.main.asyncAfter(deadline: .now() + ReactionTapBounce.settleDelay) {
            if bouncingEmoji == emoji { bouncingEmoji = nil }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ReactionTapBounce.commitDelay) {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                onReact(emoji)
            }
        }
    }
}

/// Hop after jump-to-quote. `.task(id:)` runs when the row appears already highlighted
/// (off-screen originals). Bounce is sequenced outside the list scroll transaction.
private struct MessageHighlightBounceModifier: ViewModifier {
    let pulseToken: Int
    @State private var scale: CGFloat = 1
    @State private var lift: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(y: lift)
            .zIndex(pulseToken > 0 ? 2 : 0)
            .onChange(of: pulseToken) { token in
                guard token <= 0 else { return }
                scale = 1
                lift = 0
            }
            .task(id: pulseToken) {
                guard pulseToken > 0 else { return }
                await playBounce()
            }
    }

    @MainActor
    private func playBounce() async {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            scale = 1
            lift = 0
        }
        // Jump-to-message uses withAnimation on the list; wait it out or the peak is merged away.
        try? await Task.sleep(for: .milliseconds(240))
        guard !Task.isCancelled, pulseToken > 0 else { return }

        var pop = Transaction()
        pop.animation = ChatScrollAnimation.highlightPop
        withTransaction(pop) {
            scale = ChatScrollAnimation.highlightPeakScale
            lift = ChatScrollAnimation.highlightLift
        }

        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled, pulseToken > 0 else { return }

        var settle = Transaction()
        settle.animation = ChatScrollAnimation.highlightSettle
        withTransaction(settle) {
            scale = 1
            lift = 0
        }
    }
}
