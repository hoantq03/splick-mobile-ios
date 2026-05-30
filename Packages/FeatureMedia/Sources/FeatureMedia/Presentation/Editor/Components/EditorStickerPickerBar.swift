import DesignSystem
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct EditorStickerPickerBar: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var category: EditorStickerCategory = .widget
    @State private var symbolCategory: EditorSymbolCategory = .popular
    @State private var emojiCategory: EditorEmojiCategory = .smileys
    @State private var searchText = ""
    @State private var gifPickerItems: [PhotosPickerItem] = []

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            headerRow
            subcategoryRow
            if showsSearchField {
                searchField
            }
            ScrollView {
                contentGrid
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.bottom, SplickTheme.Spacing.xs)
            }
            .frame(maxHeight: 190)
        }
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(.ultraThinMaterial.opacity(0.92))
        .onChange(of: gifPickerItems) { items in
            Task { await importGifItems(items) }
        }
    }

    private var headerRow: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(EditorStickerCategory.allCases) { tab in
                        Button {
                            category = tab
                            searchText = ""
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.caption.weight(.semibold))
                                Text(tab.label)
                                    .font(SplickTheme.Typography.captionBold)
                            }
                            .foregroundStyle(category == tab ? .white : .white.opacity(0.65))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                if category == tab {
                                    Capsule().fill(SplickTheme.Colors.primaryGradient)
                                } else {
                                    Capsule().fill(Color.white.opacity(0.12))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if viewModel.selectedStickerID != nil {
                Button {
                    viewModel.deleteSelectedSticker()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
    }

    @ViewBuilder
    private var subcategoryRow: some View {
        switch category {
        case .icon:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EditorSymbolCategory.allCases) { tab in
                        subcategoryChip(title: tab.label, isActive: symbolCategory == tab) {
                            symbolCategory = tab
                        }
                    }
                    Text("\(EditorSFSymbolCatalog.deviceSymbolCount) icon")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
            }
        case .emoji:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EditorEmojiCategory.allCases) { tab in
                        subcategoryChip(title: tab.label, isActive: emojiCategory == tab) {
                            emojiCategory = tab
                        }
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
            }
        case .widget, .gif:
            EmptyView()
        }
    }

    private var showsSearchField: Bool {
        category == .icon || category == .emoji
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
            TextField(category == .icon ? "Tìm SF Symbol..." : "Tìm emoji...", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.12)))
        .padding(.horizontal, SplickTheme.Spacing.md)
    }

    @ViewBuilder
    private var contentGrid: some View {
        switch category {
        case .widget:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(WidgetStickerTemplate.allCases) { template in
                    Button {
                        viewModel.addSticker(.widget(template))
                        haptic()
                    } label: {
                        EditorStickerContentView(kind: .widget(template))
                            .scaleEffect(0.72)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .icon:
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(filteredSymbols, id: \.self) { name in
                    Button {
                        viewModel.addSticker(.symbol(name: name, tint: EditorSFSymbolCatalog.tint(for: name)))
                        haptic()
                    } label: {
                        Image(systemName: name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(EditorSFSymbolCatalog.tint(for: name)))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .emoji:
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(filteredEmojis, id: \.self) { emoji in
                    Button {
                        viewModel.addSticker(.emoji(emoji))
                        haptic()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .gif:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                PhotosPicker(selection: $gifPickerItems, maxSelectionCount: 1, matching: .any(of: [.images])) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Thư viện")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)

                ForEach(viewModel.gifGallery) { sample in
                    Button {
                        viewModel.addGifStickerFromGallery(sample)
                        haptic()
                    } label: {
                        EditorGifImageView(data: sample.data)
                            .frame(maxWidth: .infinity)
                            .frame(height: 88)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                            .clipped()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredSymbols: [String] {
        EditorSFSymbolCatalog.search(searchText, in: searchText.isEmpty ? symbolCategory : nil)
    }

    private var filteredEmojis: [String] {
        if !searchText.isEmpty {
            return EditorEmojiCatalog.search(searchText, recent: viewModel.recentEmojis)
        }
        return EditorEmojiCatalog.emojis(in: emojiCategory, recent: viewModel.recentEmojis)
    }

    private func subcategoryChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isActive ? .bold : .medium))
                .foregroundStyle(isActive ? .white : .white.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    if isActive {
                        Capsule().fill(Color.white.opacity(0.22))
                    } else {
                        Capsule().fill(Color.white.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func importGifItems(_ items: [PhotosPickerItem]) async {
        defer { gifPickerItems = [] }
        guard let item = items.first,
              let data = try? await item.loadTransferable(type: Data.self),
              EditorGifDecoder.isGif(data) else { return }
        viewModel.addGifSticker(data: data)
        haptic()
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
