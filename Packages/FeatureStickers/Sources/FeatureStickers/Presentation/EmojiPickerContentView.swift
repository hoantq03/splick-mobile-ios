import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

enum EmojiPickerEntry: Identifiable {
    case custom(CustomEmoji)
    case system(SystemEmojiEntry)

    var id: String {
        switch self {
        case .custom(let emoji):
            return "custom-\(emoji.id.uuidString)"
        case .system(let emoji):
            return "system-\(emoji.emoji)"
        }
    }
}

public struct EmojiPickerContentView: View {
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @EnvironmentObject private var languageService: LanguageService

    let currentUserId: UUID?
    let searchQuery: String
    let onPick: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    public init(
        currentUserId: UUID?,
        searchQuery: String = "",
        onPick: @escaping (String) -> Void
    ) {
        self.currentUserId = currentUserId
        self.searchQuery = searchQuery
        self.onPick = onPick
    }

    private var myEmojis: [CustomEmoji] {
        if let currentUserId {
            return emojiStore.emojis(ownedBy: currentUserId)
        }
        // Fallback when caller forgot user id — still surface loaded custom emojis.
        return emojiStore.allEmojis
    }

    private var allEntries: [EmojiPickerEntry] {
        myEmojis.map(EmojiPickerEntry.custom) + EmojiCatalog.systemEntries.map(EmojiPickerEntry.system)
    }

    private var normalizedSearchQuery: String {
        normalizedSearchText(searchQuery)
    }

    private var filteredEntries: [EmojiPickerEntry] {
        guard !normalizedSearchQuery.isEmpty else { return allEntries }
        return allEntries.filter(matchesSearch)
    }

    public var body: some View {
        Group {
            if filteredEntries.isEmpty {
                Text(languageService.text(.stickersEmojiNotFound))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredEntries) { entry in
                        emojiButton(for: entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func emojiButton(for entry: EmojiPickerEntry) -> some View {
        switch entry {
        case .custom(let emoji):
            Button {
                onPick(emoji.colonCode)
            } label: {
                EmojiView(value: emoji.colonCode, size: 28)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        case .system(let emoji):
            Button {
                onPick(emoji.emoji)
            } label: {
                Text(emoji.emoji)
                    .font(.system(size: 28))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func matchesSearch(_ entry: EmojiPickerEntry) -> Bool {
        switch entry {
        case .custom(let emoji):
            return searchableText(for: emoji.shortcode).contains(normalizedSearchQuery)
                || searchableText(for: emoji.colonCode).contains(normalizedSearchQuery)
        case .system(let emoji):
            if searchableText(for: emoji.emoji).contains(normalizedSearchQuery) {
                return true
            }
            return emoji.keywords.contains { keyword in
                searchableText(for: keyword).contains(normalizedSearchQuery)
            }
        }
    }

    private func searchableText(for value: String) -> String {
        normalizedSearchText(value)
    }

    private func normalizedSearchText(_ value: String) -> String {
        let folded = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        return String(
            folded.unicodeScalars.filter { scalar in
                CharacterSet.alphanumerics.contains(scalar)
            }
        )
    }
}
