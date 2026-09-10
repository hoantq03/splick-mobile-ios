import SwiftUI
import DesignSystem
import Localization
import SplickDomain

/// Nested reply quote — hugs sender + snippet width (capped by [maxContentWidth]).
/// Corner radius pairs with [MessageThreadRowLayout.bubbleCornerRadius]
/// (Android `MessageQuotedReply` twin).
struct MessageQuotedReplyView: View {
    @EnvironmentObject private var languageService: LanguageService

    let preview: MessageReplyPreview
    let isOutgoing: Bool
    /// When `true`, quote sits inside the colored text bubble (outgoing uses light-on-gradient).
    /// When `false`, quote sits above media on the chat background (surface colors).
    var usesBubbleTextColors: Bool = true
    /// Caps quote width so long replies wrap instead of stretching the bubble.
    var maxContentWidth: CGFloat? = nil
    /// When `true`, the quoted original has been recalled — show unsent placeholder text.
    var quotedMessageRecalled: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            // simultaneous — exclusive onTapGesture steals the list reply-swipe pan
            // when the finger starts on the quoted strip.
            quotedContent
                .contentShape(RoundedRectangle(
                    cornerRadius: MessageThreadRowLayout.quoteCornerRadius,
                    style: .continuous
                ))
                .simultaneousGesture(TapGesture().onEnded(onTap))
                .accessibilityAddTraits(.isButton)
        } else {
            quotedContent
        }
    }

    private var quotedContent: some View {
        let core = HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(
                cornerRadius: MessageThreadRowLayout.quoteAccentCornerRadius,
                style: .continuous
            )
            .fill(accentColor)
            .frame(width: MessageThreadRowLayout.quoteAccentWidth)
            .padding(.vertical, 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)

                Text(quotedText)
                    .font(.system(size: 11))
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, MessageThreadRowLayout.quoteHorizontalPaddingLeading)
        .padding(.trailing, MessageThreadRowLayout.quoteHorizontalPaddingTrailing)
        .padding(.vertical, MessageThreadRowLayout.quoteVerticalPadding)

        return Group {
            if let maxContentWidth {
                ViewThatFits(in: .horizontal) {
                    core.fixedSize(horizontal: true, vertical: true)
                    core
                        .frame(maxWidth: maxContentWidth, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: maxContentWidth, alignment: .leading)
            } else {
                core.fixedSize(horizontal: true, vertical: true)
            }
        }
        .background {
            RoundedRectangle(
                cornerRadius: MessageThreadRowLayout.quoteCornerRadius,
                style: .continuous
            )
            .fill(cardFill)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: MessageThreadRowLayout.quoteCornerRadius,
                style: .continuous
            )
        )
    }

    private var cardFill: Color {
        if usesBubbleTextColors {
            return isOutgoing
                ? Color.white.opacity(0.16)
                : SplickTheme.Colors.background.opacity(0.72)
        }
        return SplickTheme.Colors.secondaryBackground
    }

    private var displayName: String {
        preview.senderDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? preview.senderDisplayName!
            : languageService.text(.messagingReplyUnknownSender)
    }

    private var quotedText: String {
        if quotedMessageRecalled {
            return languageService.text(.messagingMessageRecalled)
        }
        let trimmed = preview.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if preview.hasImageAttachment {
            return languageService.text(.messagingReplyPhoto)
        }
        return languageService.text(.messagingReplyEmpty)
    }

    private var accentColor: Color {
        guard usesBubbleTextColors, isOutgoing else {
            return SplickTheme.Colors.primaryGradientStart
        }
        return Color.white.opacity(0.88)
    }

    private var nameColor: Color {
        guard usesBubbleTextColors, isOutgoing else {
            return SplickTheme.Colors.primaryGradientStart
        }
        return Color.white.opacity(0.95)
    }

    private var textColor: Color {
        guard usesBubbleTextColors, isOutgoing else {
            return SplickTheme.Colors.textSecondary
        }
        return Color.white.opacity(0.78)
    }
}
