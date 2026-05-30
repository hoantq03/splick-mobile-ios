import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct ReactionDetailSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    let summaries: [UserReactionSummary]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(summaries) { summary in
                Section {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        AvatarView(
                            imageURL: summary.user.avatarURL,
                            name: summary.user.displayName,
                            size: .medium
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.user.displayName)
                                .font(SplickTheme.Typography.headline)
                            Text("@\(summary.user.username)")
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }
                    }
                    .padding(.vertical, SplickTheme.Spacing.xxs)

                    ForEach(summary.emojiCounts, id: \.emoji) { item in
                        HStack {
                            Text(item.emoji)
                                .font(.title)
                            Text("×\(item.count)")
                                .font(SplickTheme.Typography.title)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(languageService.format(.feedReactionsCount, summary.totalCount))
                }
            }
            .navigationTitle(languageService.text(.feedReactionsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
        }
    }
}
