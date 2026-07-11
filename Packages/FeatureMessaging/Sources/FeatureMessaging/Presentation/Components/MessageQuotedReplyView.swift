import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct MessageQuotedReplyView: View {
    @EnvironmentObject private var languageService: LanguageService

    let preview: MessageReplyPreview
    let isOutgoing: Bool

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)

                Text(quotedText)
                    .font(.system(size: 11))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        isOutgoing ? Color.white.opacity(0.85) : SplickTheme.Colors.primaryGradientStart
    }

    private var nameColor: Color {
        isOutgoing ? Color.white.opacity(0.95) : SplickTheme.Colors.primaryGradientStart
    }

    private var textColor: Color {
        isOutgoing ? Color.white.opacity(0.78) : SplickTheme.Colors.textSecondary
    }
}
