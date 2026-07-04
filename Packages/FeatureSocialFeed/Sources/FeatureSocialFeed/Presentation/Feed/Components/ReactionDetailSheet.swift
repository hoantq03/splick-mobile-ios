import SwiftUI
import DesignSystem
import Localization
import SplickDomain

private enum ReactionDetailMetrics {
    static let identityWidth: CGFloat = 74
    static let reactionBubbleSize: CGFloat = 46
}

struct ReactionDetailSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    let summaries: [UserReactionSummary]
    let onUserTap: (UserSummary) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                    if summaries.isEmpty {
                        Text(languageService.text(.notificationInboxEmpty))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(summaries) { summary in
                            reactionSummaryRow(summary)
                        }
                    }
                }
            }
            .padding(SplickTheme.Spacing.md)
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.feedReactionsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
        }
    }

    private func reactionSummaryRow(_ summary: UserReactionSummary) -> some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.md) {
            Button {
                onUserTap(summary.user)
            } label: {
                VStack(spacing: SplickTheme.Spacing.xs) {
                    AvatarView(
                        imageURL: summary.user.avatarURL,
                        name: summary.user.displayName,
                        size: .medium,
                        userId: summary.user.id
                    )

                    Text(shortDisplayName(summary.user.displayName, fallback: summary.user.username))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(width: ReactionDetailMetrics.identityWidth)
                }
            }
            .buttonStyle(.plain)
            .frame(width: ReactionDetailMetrics.identityWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                    ForEach(summary.emojiCounts, id: \.emoji) { item in
                        emojiCountBubble(item)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
    }

    private func emojiCountBubble(_ item: UserEmojiCount) -> some View {
        ZStack(alignment: .topTrailing) {
            EmojiView(value: item.emoji, size: 28)
                .frame(
                    width: ReactionDetailMetrics.reactionBubbleSize,
                    height: ReactionDetailMetrics.reactionBubbleSize
                )
                .background(
                    Circle()
                        .fill(SplickTheme.Colors.tertiaryBackground)
                )
                .overlay(
                    Circle()
                        .strokeBorder(SplickTheme.Colors.divider.opacity(0.35), lineWidth: 1)
                )

            Text("x\(item.count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(SplickTheme.Colors.primaryGradientStart)
                )
                .offset(x: 8, y: -6)
        }
        .padding(.top, 4)
        .padding(.trailing, 8)
    }

    private func shortDisplayName(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? fallback : trimmed
        return resolved.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? resolved
    }
}
