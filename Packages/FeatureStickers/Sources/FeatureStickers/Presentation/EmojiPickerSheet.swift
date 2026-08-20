import SwiftUI
import PhotosUI
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureStickers

private enum AllEmojiEntry: Identifiable {
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

private enum EmojiPickerTab: String, CaseIterable, Identifiable {
    case unicode
    case custom

    var id: String { rawValue }
}

/// Popup for picking a reaction emoji or inserting a custom emoji into text.
public struct EmojiPickerSheet: View {
    public enum Mode {
        /// Reaction bar: quick slots + optional Done to persist preferences.
        case reaction
        /// Comment composer: pick once and dismiss without quick-slot UI.
        case inlineInsert
    }

    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    @ObservedObject private var preferences = QuickReactionPreferences.shared

    let currentUserId: UUID?
    let mode: Mode
    let onPick: (String) -> Void
    var onOpenUpload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draftQuickEmojis: [String] = QuickReactionPreferences.defaultEmojis
    @State private var selectedSlot: Int?
    @State private var selectedTab: EmojiPickerTab
    @State private var selectedUploadPhotoItem: PhotosPickerItem?
    @State private var uploadSourceImage: UIImage?
    @State private var isPreparingUpload = false
    @State private var uploadPreparationError: String?
    @State private var showEmojiComposer = false
    @State private var searchQuery = ""

    public init(
        currentUserId: UUID?,
        mode: Mode = .reaction,
        onPick: @escaping (String) -> Void,
        onOpenUpload: (() -> Void)? = nil
    ) {
        self.currentUserId = currentUserId
        self.mode = mode
        self.onPick = onPick
        self.onOpenUpload = onOpenUpload
        _selectedTab = State(initialValue: mode == .inlineInsert ? .custom : .unicode)
    }

    private let unicodeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
    private let customColumns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)

    private var myEmojis: [CustomEmoji] {
        currentUserId.map { emojiStore.emojis(ownedBy: $0) } ?? []
    }

    private var allEmojiEntries: [AllEmojiEntry] {
        myEmojis.map(AllEmojiEntry.custom) + EmojiCatalog.systemEntries.map(AllEmojiEntry.system)
    }

    private var normalizedSearchQuery: String {
        normalizedSearchText(searchQuery)
    }

    private var filteredAllEmojiEntries: [AllEmojiEntry] {
        guard !normalizedSearchQuery.isEmpty else { return allEmojiEntries }
        return allEmojiEntries.filter(matchesSearch(_:))
    }

    private var filteredMyEmojis: [CustomEmoji] {
        guard !normalizedSearchQuery.isEmpty else { return myEmojis }
        return myEmojis.filter { emoji in
            searchableText(for: emoji.shortcode).contains(normalizedSearchQuery)
                || searchableText(for: emoji.colonCode).contains(normalizedSearchQuery)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    if mode == .reaction {
                        quickBarSection
                    }
                    tabPicker
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
                if mode == .inlineInsert {
                    ToolbarItem(placement: .primaryAction) {
                        uploadPickerButton(style: .iconOnly)
                    }
                }
            }
            .onAppear {
                if mode == .reaction {
                    draftQuickEmojis = preferences.quickEmojis
                }
            }
            .onChange(of: selectedUploadPhotoItem) { item in
                guard item != nil else { return }
                Task { await prepareUploadImage(from: item) }
            }
            .alert(
                languageService.text(.commonError),
                isPresented: Binding(
                    get: { uploadPreparationError != nil },
                    set: { if !$0 { uploadPreparationError = nil } }
                )
            ) {
                Button(languageService.text(.commonOK), role: .cancel) { uploadPreparationError = nil }
            } message: {
                Text(uploadPreparationError ?? "")
            }
        }
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: languageService.text(.stickersEmojiSearch))
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showEmojiComposer, onDismiss: {
            uploadSourceImage = nil
        }) {
            if let uploadSourceImage, let customEmojiDependencies {
                CustomEmojiComposerSheet(
                    sourceImage: uploadSourceImage,
                    uploadMediaUseCase: customEmojiDependencies.uploadMediaUseCase,
                    addEmojiUseCase: customEmojiDependencies.addEmojiUseCase,
                    onUploaded: { _ in
                        selectedTab = .custom
                    }
                )
            }
        }
    }

    private var tabPicker: some View {
        Picker(languageService.text(.stickersEmojiSourceA11y), selection: $selectedTab) {
            Text(languageService.text(.feedEmojiPickerAllTitle)).tag(EmojiPickerTab.unicode)
            Text(languageService.text(.stickersYourEmoji)).tag(EmojiPickerTab.custom)
        }
        .pickerStyle(.segmented)
    }

    private var quickBarSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                Text(languageService.text(.feedEmojiPickerQuickBarTitle))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Spacer()
                uploadPickerButton(style: .textOnly)
            }

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
            EmojiView(value: draftQuickEmojis[index], size: 26)
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
        EmojiPickerContentView(
            currentUserId: currentUserId,
            searchQuery: searchQuery,
            onPick: handleEmojiTap
        )
    }

    private var customEmojiSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            if myEmojis.isEmpty {
                Text(languageService.text(.feedCustomEmojiEmpty))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if filteredMyEmojis.isEmpty {
                emptySearchState
            } else {
                LazyVGrid(columns: customColumns, spacing: 10) {
                    ForEach(filteredMyEmojis) { emoji in
                        EmojiView(value: emoji.colonCode, size: 36)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(SplickTheme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture { handleEmojiTap(emoji.colonCode) }
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func allEmojiButton(for entry: AllEmojiEntry) -> some View {
        switch entry {
        case .custom(let emoji):
            Button {
                handleEmojiTap(emoji.colonCode)
            } label: {
                EmojiView(value: emoji.colonCode, size: 28)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        case .system(let emoji):
            Button {
                handleEmojiTap(emoji.emoji)
            } label: {
                Text(emoji.emoji)
                    .font(.system(size: 28))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptySearchState: some View {
        Text(languageService.text(.stickersEmojiNotFound))
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleEmojiTap(_ emoji: String) {
        if mode == .reaction, let slot = selectedSlot {
            var updatedQuickEmojis = draftQuickEmojis
            updatedQuickEmojis[slot] = emoji
            draftQuickEmojis = updatedQuickEmojis
            preferences.saveQuickEmojis(updatedQuickEmojis)
            selectedSlot = nil
            return
        }

        dismiss()

        // Dismiss first so the sheet animation stays responsive before mutating the feed.
        DispatchQueue.main.async {
            onPick(emoji)
        }
    }

    @ViewBuilder
    private func uploadPickerButton(style: UploadPickerButtonStyle) -> some View {
        PhotosPicker(selection: $selectedUploadPhotoItem, matching: .images) {
            if style == .iconOnly {
                if isPreparingUpload {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle")
                }
            } else {
                Group {
                    if isPreparingUpload {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(languageService.text(.feedCustomEmojiAddAction))
                            .font(SplickTheme.Typography.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.10))
                .clipShape(Capsule())
            }
        }
        .disabled(isPreparingUpload || customEmojiDependencies == nil)
    }

    @MainActor
    private func prepareUploadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard customEmojiDependencies != nil else {
            uploadPreparationError = languageService.text(.stickersUploadUnavailable)
            selectedUploadPhotoItem = nil
            return
        }
        isPreparingUpload = true
        defer {
            isPreparingUpload = false
            selectedUploadPhotoItem = nil
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            uploadPreparationError = languageService.text(.stickersOpenImageFailed)
            return
        }

        uploadSourceImage = image
        showEmojiComposer = true
    }

    private func matchesSearch(_ entry: AllEmojiEntry) -> Bool {
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

private enum UploadPickerButtonStyle {
    case iconOnly
    case textOnly
}
