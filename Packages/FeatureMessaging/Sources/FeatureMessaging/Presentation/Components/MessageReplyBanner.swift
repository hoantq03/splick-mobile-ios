import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct MessageReplyBanner: View {
    @EnvironmentObject private var languageService: LanguageService

    let draft: MessageReplyDraft
    let onCancel: () -> Void

    private let barHeight: CGFloat = 24

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(SplickTheme.Colors.primaryGradientStart)
                .frame(width: 2, height: barHeight)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(languageService.text(.messagingReplyingTo)) \(draft.senderDisplayName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .lineLimit(1)

                Text(previewText)
                    .font(.system(size: 11))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(SplickTheme.Colors.tertiaryBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageService.text(.messagingReplyCancelAccessibility))
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .leading)
        .background(SplickTheme.Colors.secondaryBackground)
    }

    private var previewText: String {
        let trimmed = draft.bodySnippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if draft.hasImageAttachment {
            return languageService.text(.messagingReplyPhoto)
        }
        return languageService.text(.messagingReplyEmpty)
    }
}
