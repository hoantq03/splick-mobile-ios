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
    var isFloatingSend: Bool = false
    var floatSway: CGFloat = 0
    var presentation: Presentation = .threadRow
    /// When lifting into reaction focus, cap bubble width so text reflows instead of overflowing.
    var focusMaxContentWidth: CGFloat? = nil
    /// Shared list drag: negative (swipe left) reveals right/outgoing times;
    /// positive (swipe right) reveals left/incoming times.
    var timestampRevealTranslation: CGFloat = 0
    /// List-owned reply swipe (1:1) — reveals reply icon in the timestamp/status slot.
    var replySwipeTranslation: CGFloat = 0
    let onReact: (String) -> Void
    let onRetry: (() -> Void)?
    let onLongPress: (() -> Void)?
    let onReply: (() -> Void)?
    /// Peer avatar for the latest `.read` outgoing receipt (DIRECT).
    var readReceiptPeerAvatarURL: URL? = nil
    var readReceiptPeerName: String = ""
    var showsReadReceiptAvatar: Bool = false
    var readReceiptNamespace: Namespace.ID? = nil
    var conversationId: UUID? = nil

    @State private var imageViewerRoute: AttachmentPreviewRoute?

    /// Same optical width as the time slot so reply/time swap in place.
    private static let accessorySlotWidth: CGFloat = 46
    private static let replyIconSize: CGFloat = 16
    /// Fits `HH:mm` with caption + monospaced digits.
    private static let timestampLabelWidth: CGFloat = 46
    private static let mediaMaxWidth: CGFloat = 220
    private static let mediaCornerRadius: CGFloat = SplickTheme.CornerRadius.medium
    private static let rowSideSpacer: CGFloat = 48

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
        return Self.mediaMaxWidth
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

    /// Reply icon opens in the same slot as time, 1:1 with the finger — springs shut on release.
    private var revealedReplyIconWidth: CGFloat {
        min(abs(replySwipeTranslation), Self.accessorySlotWidth)
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
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: resolvedContentMaxWidth, alignment: isOutgoing ? .trailing : .leading)
    }

    private var threadRow: some View {
        HStack(alignment: .messageDeliveryStatus, spacing: SplickTheme.Spacing.xxs) {
            if isOutgoing {
                Spacer(minLength: Self.rowSideSpacer)
                    .allowsHitTesting(false)
            } else {
                incomingLeadingMeta
            }

            bubbleCluster

            if isOutgoing {
                outgoingTrailingMeta
            } else {
                Spacer(minLength: Self.rowSideSpacer)
                    .allowsHitTesting(false)
            }
        }
        .padding(.top, topSpacing)
    }

    @ViewBuilder
    private var incomingLeadingMeta: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.xxs) {
            replyRevealIcon
            timestampRevealLabel
        }
        .fixedSize(horizontal: true, vertical: true)
        .alignmentGuide(.messageDeliveryStatus) { dimensions in
            dimensions[VerticalAlignment.center]
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var outgoingTrailingMeta: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.xxs) {
            if message.deliveryStatus != .failed {
                MessageStatusIndicator(
                    status: message.deliveryStatus,
                    showsReadAvatar: showsReadReceiptAvatar,
                    readAvatarURL: readReceiptPeerAvatarURL,
                    readAvatarName: readReceiptPeerName,
                    readAvatarNamespace: readReceiptNamespace,
                    conversationId: conversationId
                )
            }
            replyRevealIcon
            timestampRevealLabel
        }
        .fixedSize(horizontal: true, vertical: true)
        .alignmentGuide(.messageDeliveryStatus) { dimensions in
            dimensions[VerticalAlignment.center]
        }
        .allowsHitTesting(false)
    }

    /// Reply affordance in the time slot — width tracks the finger 1:1, then snaps closed.
    private var replyRevealIcon: some View {
        Image(systemName: "arrowshape.turn.up.left.fill")
            .font(.system(size: Self.replyIconSize, weight: .semibold))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(width: Self.accessorySlotWidth, height: Self.accessorySlotWidth)
            .frame(
                width: revealedReplyIconWidth,
                alignment: isOutgoing ? .leading : .trailing
            )
            .clipped()
            .opacity(revealedReplyIconWidth < 4 ? 0 : Double(min(revealedReplyIconWidth / 14, 1)))
            .accessibilityHidden(revealedReplyIconWidth < 8)
            .allowsHitTesting(false)
    }

    /// Time stays tucked under the outer edge; width opens 1:1 with the finger.
    private var timestampRevealLabel: some View {
        Text(formattedTimestamp)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .monospacedDigit()
            .lineLimit(1)
            .frame(
                width: Self.timestampLabelWidth,
                alignment: isOutgoing ? .leading : .trailing
            )
            .frame(
                width: revealedTimestampWidth,
                alignment: isOutgoing ? .leading : .trailing
            )
            .clipped()
            .alignmentGuide(.messageDeliveryStatus) { dimensions in
                dimensions[VerticalAlignment.center]
            }
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
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: MessageReactionAnchorFrameKey.self,
                    value: presentation == .threadRow ? [message.id: geo.frame(in: .global)] : [:]
                )
            }
        }
        .messageSendFloat(isActive: isFloatingSend && presentation == .threadRow, lateralSway: floatSway)
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
            if isHighlighted {
                RoundedRectangle(cornerRadius: Self.mediaCornerRadius, style: .continuous)
                    .stroke(SplickTheme.Colors.primaryGradientStart.opacity(0.85), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: Self.mediaCornerRadius, style: .continuous)
                            .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.15))
                    )
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

    /// Quote sits above media, outside the colored text bubble, so it must not use
    /// outgoing white text (that is invisible on the chat background).
    private func mediaReplyPreview(_ preview: MessageReplyPreview) -> some View {
        MessageQuotedReplyView(
            preview: preview,
            isOutgoing: isOutgoing,
            usesBubbleTextColors: false
        )
        .padding(.horizontal, SplickTheme.Spacing.xs)
        .padding(.vertical, SplickTheme.Spacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SplickTheme.Colors.secondaryBackground)
        }
    }

    private var textBubbleBody: some View {
        // Quote + text share one clipped bubble. Putting the quote outside used
        // outgoing white labels on the chat background, so the original message
        // disappeared. `frame(maxWidth:)` still avoids ViewThatFits double-measure.
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            if imageAttachments.isEmpty, let preview = message.replyPreview {
                MessageQuotedReplyView(
                    preview: preview,
                    isOutgoing: isOutgoing,
                    usesBubbleTextColors: true
                )
            }
            if hasTextBody {
                messageTextLabel(lineLimit: nil)
            }
        }
        .frame(maxWidth: textWrapMaxWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, SplickTheme.Spacing.sm + 2)
        .padding(.vertical, SplickTheme.Spacing.xs + 2)
        .frame(minWidth: textReactionMinWidth, alignment: .leading)
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
        let mediaWidth = min(resolvedContentMaxWidth, Self.mediaMaxWidth)
        if imageAttachments.count == 1,
           let attachment = imageAttachments.first,
           attachment.url.isLikelyAnimatedImage {
            InlineGifAttachmentView(
                url: attachment.url,
                widthFraction: mediaWidth / max(UIScreen.main.bounds.width, 1),
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
            let attachment = imageAttachments[index]
            if attachment.url.isLikelyAnimatedImage {
                RemoteGifFullscreenPreview(url: attachment.url) {
                    imageViewerRoute = nil
                }
            } else {
                let urls = imageAttachments.map(\.url)
                RemoteImageFullscreenPreview(
                    urls: urls,
                    initialIndex: index,
                    onDismiss: { imageViewerRoute = nil }
                )
            }
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
            context[VerticalAlignment.center]
        }
    }

    static let messageDeliveryStatus = VerticalAlignment(MessageDeliveryStatusAlignment.self)
}

private struct MessageDeliveryStatusAnchor: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.alignmentGuide(.messageDeliveryStatus) { dimensions in
                dimensions[VerticalAlignment.center]
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
