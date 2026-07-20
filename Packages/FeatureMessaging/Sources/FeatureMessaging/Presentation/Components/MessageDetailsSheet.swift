import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct MessageDetailsSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    let message: ChatMessage
    let displayNameForUserId: (UUID) -> String

    private var sentAtText: String {
        Self.fullDateTimeFormatter(locale: languageService.locale).string(from: message.createdAt)
    }

    private var reactionGroups: [(emoji: String, reactors: [UUID])] {
        var order: [String] = []
        var grouped: [String: [UUID]] = [:]
        for reaction in message.reactions {
            if grouped[reaction.emoji] == nil {
                order.append(reaction.emoji)
                grouped[reaction.emoji] = []
            }
            if grouped[reaction.emoji]?.contains(reaction.userId) != true {
                grouped[reaction.emoji]?.append(reaction.userId)
            }
        }
        return order.map { emoji in
            (emoji: emoji, reactors: grouped[emoji] ?? [])
        }
    }

    private var messageBodyText: String {
        let trimmed = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if message.hasImageAttachments {
            return languageService.text(.messagingReplyPhoto)
        }
        return languageService.text(.messagingMessageDetailsNoContent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    messageSection
                    sentAtSection
                    reactionsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SplickTheme.Spacing.md)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.messagingMessageDetailsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(messageBodyText)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if message.hasImageAttachments {
                Label {
                    Text(photoAttachmentLabel)
                        .font(SplickTheme.Typography.caption)
                } icon: {
                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
        .padding(SplickTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
    }

    private var photoAttachmentLabel: String {
        let count = message.imageAttachments.count
        let photo = languageService.text(.messagingReplyPhoto)
        return count <= 1 ? photo : "\(count) × \(photo)"
    }

    private var sentAtSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.messagingMessageDetailsSentAt))
                .font(SplickTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            Text(sentAtText)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
        }
    }

    private var reactionsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.messagingMessageDetailsReactions))
                .font(SplickTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            if reactionGroups.isEmpty {
                Text(languageService.text(.messagingMessageDetailsNoReactions))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            } else {
                VStack(spacing: SplickTheme.Spacing.sm) {
                    ForEach(reactionGroups, id: \.emoji) { group in
                        reactionGroupRow(emoji: group.emoji, reactors: group.reactors)
                    }
                }
            }
        }
    }

    private func reactionGroupRow(emoji: String, reactors: [UUID]) -> some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.md) {
            EmojiView(value: emoji, size: 28)
                .frame(width: 40, height: 40)
                .background(Circle().fill(SplickTheme.Colors.tertiaryBackground))

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                Text("×\(reactors.count)")
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                ForEach(reactors, id: \.self) { userId in
                    Text(displayNameForUserId(userId))
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
    }

    private static func fullDateTimeFormatter(locale: AppLocale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.rawValue)
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }
}
