import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureStickers

private enum EmojiPickerTab: String, CaseIterable, Identifiable {
    case unicode
    case custom

    var id: String { rawValue }
}

/// Popup for picking a reaction and customizing the six quick-reaction slots on the feed bar.
struct EmojiPickerSheet: View {
    enum Mode {
        /// Reaction bar: quick slots + optional Done to persist preferences.
        case reaction
        /// Comment composer: pick once and dismiss without quick-slot UI.
        case inlineInsert
    }

    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    @ObservedObject private var preferences = QuickReactionPreferences.shared

    let groupId: UUID?
    let mode: Mode
    let onPick: (String) -> Void
    var onOpenUpload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draftQuickEmojis: [String] = QuickReactionPreferences.defaultEmojis
    @State private var selectedSlot: Int?
    @State private var selectedTab: EmojiPickerTab

    init(
        groupId: UUID?,
        mode: Mode = .reaction,
        onPick: @escaping (String) -> Void,
        onOpenUpload: (() -> Void)? = nil
    ) {
        self.groupId = groupId
        self.mode = mode
        self.onPick = onPick
        self.onOpenUpload = onOpenUpload
        // Default to "Của nhóm" tab when there's a group and we're inserting into comment.
        // For reaction mode keep unicode first (user is reacting, not uploading).
        _selectedTab = State(initialValue: (groupId != nil && mode == .inlineInsert) ? .custom : .unicode)
    }

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
                    if mode == .reaction {
                        quickBarSection
                    }
                    if groupId != nil {
                        tabPicker
                    }
                    switch selectedTab {
                    case .unicode:
                        if groupId != nil {
                            customEmojiQuickBanner
                        }
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
                if mode == .reaction {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(languageService.text(.commonDone)) {
                            preferences.saveQuickEmojis(draftQuickEmojis)
                            dismiss()
                        }
                    }
                }
                if onOpenUpload != nil, groupId != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            onOpenUpload?()
                        } label: {
                            Label(languageService.text(.feedCustomEmojiUploadAction), systemImage: "plus.circle")
                        }
                    }
                }
            }
            .onAppear {
                if mode == .reaction {
                    draftQuickEmojis = preferences.quickEmojis
                }
            }
            .task(id: groupId) {
                guard let groupId, let fetcher = customEmojiDependencies?.fetcher else { return }
                await emojiStore.load(groupId: groupId, fetcher: fetcher)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var customEmojiQuickBanner: some View {
        let emojis = groupId.map { emojiStore.emojis(for: $0) } ?? []
        return Button {
            if emojis.isEmpty, let onOpenUpload {
                onOpenUpload()
            } else {
                selectedTab = .custom
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: emojis.isEmpty ? "plus.circle.fill" : "face.smiling.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(emojis.isEmpty
                     ? languageService.text(.feedCustomEmojiUploadAction)
                     : languageService.text(.feedEmojiPickerCustomTabTitle))
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SplickTheme.Colors.primaryGradientStart.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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
            }

            if onOpenUpload != nil {
                Button(action: { onOpenUpload?() }) {
                    Label(languageService.text(.feedCustomEmojiUploadAction), systemImage: "square.and.arrow.up")
                        .font(SplickTheme.Typography.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            let emojis = groupId.map { emojiStore.emojis(for: $0) } ?? []
            if emojis.isEmpty {
                Button {
                    onOpenUpload?()
                } label: {
                    Text(languageService.text(.feedCustomEmojiEmpty))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(onOpenUpload == nil)
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
        if mode == .reaction, let slot = selectedSlot {
            draftQuickEmojis[slot] = emoji
            selectedSlot = nil
            return
        }

        if mode == .reaction {
            preferences.saveQuickEmojis(draftQuickEmojis)
        }
        onPick(emoji)
        dismiss()
    }
}
