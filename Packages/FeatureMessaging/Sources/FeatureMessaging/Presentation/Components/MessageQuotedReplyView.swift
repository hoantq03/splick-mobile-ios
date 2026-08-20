import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct MessageQuotedReplyView: View {
    @EnvironmentObject private var languageService: LanguageService

    let preview: MessageReplyPreview
    let isOutgoing: Bool
    var usesBubbleTextColors: Bool = true

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)

                Text(quotedText)
                    .font(.system(size: 11))
                    .foregroundStyle(textColor)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 6)
        .padding(.vertical, 5)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let cardFill {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cardFill)
            }
        }
    }

    private var cardFill: Color? {
        guard usesBubbleTextColors else { return nil }
        return isOutgoing
            ? Color.white.opacity(0.16)
            : SplickTheme.Colors.background.opacity(0.72)
    }

    private var displayName: String {
        preview.senderDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? preview.senderDisplayName!
            : languageService.text(.messagingReplyUnknownSender)
    }

    private var quotedText: String {
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
        return Color.white.opacity(0.85)
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
