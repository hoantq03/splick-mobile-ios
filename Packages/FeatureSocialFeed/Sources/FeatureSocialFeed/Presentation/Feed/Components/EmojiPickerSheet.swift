import SwiftUI
import DesignSystem
import Localization
import SplickDomain

private enum EmojiPickerTab: String, CaseIterable, Identifiable {
    case unicode
    case custom

    var id: String { rawValue }
}

/// Popup for picking a reaction and customizing the six quick-reaction slots on the feed bar.
struct EmojiPickerSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.customEmojiStore) private var emojiStore
    @ObservedObject private var preferences = QuickReactionPreferences.shared

    let groupId: UUID?
    let onPick: (String) -> Void
    var onOpenUpload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draftQuickEmojis: [String] = QuickReactionPreferences.defaultEmojis
    @State private var selectedSlot: Int?
    @State private var selectedTab: EmojiPickerTab = .unicode

    private let unicodeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
    private let customColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private static let emojiCatalog: [String] = [
        "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
        "😂", "🤣", "😊", "😍", "🥰", "😘", "😎", "🤩",
        "😮", "😲", "😢", "😭", "😡", "🤬", "👏", "🙌",
        "🔥", "💯", "✨", "🎉", "👍", "👎", "🙏", "💪",
        "😴", "🤔", "😬", "🥳", "🤯", "😱", "💀", "🫶",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    quickBarSection
                    if groupId != nil {
                        tabPicker
                    }
                    switch selectedTab {
                    case .unicode:
                        emojiGridSection
                    case .custom:
                        customEmojiSection
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, SplickTheme.Spacing.md)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.feedEmojiPickerTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) {
                        preferences.saveQuickEmojis(draftQuickEmojis)
                        dismiss()
                    }
                }
            }
            .onAppear {
                draftQuickEmojis = preferences.quickEmojis
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var tabPicker: some View {
        Picker("Emoji source", selection: $selectedTab) {
            Text(languageService.text(.feedEmojiPickerAllTitle)).tag(EmojiPickerTab.unicode)
            Text(languageService.text(.feedEmojiPickerCustomTabTitle)).tag(EmojiPickerTab.custom)
        }
        .pickerStyle(.segmented)
    }

    private var quickBarSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedEmojiPickerQuickBarTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            Text(languageService.text(.feedEmojiPickerQuickBarHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            HStack(spacing: 6) {
                ForEach(0..<QuickReactionPreferences.slotCount, id: \.self) { index in
                    quickSlotButton(at: index)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func quickSlotButton(at index: Int) -> some View {
        let isSelected = selectedSlot == index
        return Button {
            selectedSlot = isSelected ? nil : index
        } label: {
            EmojiView(value: draftQuickEmojis[index], groupId: groupId, size: 26)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(
                            isSelected
                                ? SplickTheme.Colors.primaryGradientStart.opacity(0.18)
                                : SplickTheme.Colors.secondaryBackground
                        )
                )
                .overlay {
                    Circle()
                        .stroke(
                            isSelected
                                ? SplickTheme.Colors.primaryGradientStart
                                : SplickTheme.Colors.divider.opacity(0.35),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private var emojiGridSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedEmojiPickerAllTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            LazyVGrid(columns: unicodeColumns, spacing: 10) {
                ForEach(Self.emojiCatalog, id: \.self) { emoji in
                    Button {
                        handleEmojiTap(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(SplickTheme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customEmojiSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack {
                Text(languageService.text(.feedEmojiPickerCustomTabTitle))
                    .font(SplickTheme.Typography.headline)
                Spacer()
                if onOpenUpload != nil {
                    Button(languageService.text(.feedCustomEmojiAddAction)) {
                        onOpenUpload?()
                    }
                    .font(SplickTheme.Typography.caption)
                }
            }

            let emojis = groupId.map { emojiStore.emojis(for: $0) } ?? []
            if emojis.isEmpty {
                Text(languageService.text(.feedCustomEmojiEmpty))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            } else {
                LazyVGrid(columns: customColumns, spacing: 10) {
                    ForEach(emojis) { emoji in
                        Button {
                            handleEmojiTap(emoji.colonCode)
                        } label: {
                            VStack(spacing: 4) {
                                EmojiView(value: emoji.colonCode, groupId: groupId, size: 36)
                                    .frame(height: 40)
                                Text(":\(emoji.shortcode):")
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(SplickTheme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func handleEmojiTap(_ emoji: String) {
        if let slot = selectedSlot {
            draftQuickEmojis[slot] = emoji
            selectedSlot = nil
            return
        }

        preferences.saveQuickEmojis(draftQuickEmojis)
        onPick(emoji)
        dismiss()
    }
}
