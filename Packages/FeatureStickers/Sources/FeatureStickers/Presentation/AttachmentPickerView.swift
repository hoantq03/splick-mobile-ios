import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

public struct AttachmentPickerView: View {
    @ObservedObject private var viewModel: GifPickerViewModel
    @EnvironmentObject private var languageService: LanguageService

    private let options: AttachmentPickerOptions
    private let currentUserId: UUID?
    private let onSelectGif: (Sticker) -> Void
    private let onSelectEmoji: (String) -> Void

    private enum GridLayout {
        static let columnsPerRow = 4
        static let spacing: CGFloat = 10
        static let cornerRadius: CGFloat = SplickTheme.CornerRadius.tile
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: GridLayout.spacing),
            count: GridLayout.columnsPerRow
        )
    }

    public init(
        viewModel: GifPickerViewModel,
        options: AttachmentPickerOptions = AttachmentPickerOptions(),
        currentUserId: UUID? = nil,
        onSelectGif: @escaping (Sticker) -> Void,
        onSelectEmoji: @escaping (String) -> Void
    ) {
        self.viewModel = viewModel
        self.options = options
        self.currentUserId = currentUserId
        self.onSelectGif = onSelectGif
        self.onSelectEmoji = onSelectEmoji
    }

    public var body: some View {
        VStack(spacing: 0) {
            AttachmentPickerCategoryBar(
                categories: viewModel.categories,
                showsCustomPack: viewModel.showsCustomPack,
                selectedCategory: viewModel.selectedCategory,
                isSearchActive: viewModel.isSearchActive,
                options: options,
                onSelect: viewModel.onCategorySelected
            )
            .padding(.top, SplickTheme.Spacing.xxs)

            if viewModel.isSearchActive, options.allowsGifSelection {
                searchBar
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.bottom, SplickTheme.Spacing.xs)
            }

            VStack(spacing: SplickTheme.Spacing.xs) {
                AttachmentPickerPanelHeader(title: panelTitle)
                    .padding(.horizontal, SplickTheme.Spacing.md)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                    .ignoresSafeArea(edges: .bottom)

                if showsSuggestionChips {
                    suggestionChips
                        .padding(.horizontal, SplickTheme.Spacing.md)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { viewModel.onAppear() }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            TextField(languageService.text(.stickersGifSearchPlaceholder), text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.onSearchTextChanged($0) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedCategory {
        case .emoji:
            ScrollView {
                EmojiPickerContentView(
                    currentUserId: currentUserId,
                    searchQuery: viewModel.searchText,
                    onPick: onSelectEmoji
                )
                .padding(.horizontal, SplickTheme.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .favorites:
            stickerGrid(state: viewModel.favoritesState, emptyMessage: languageService.text(.stickersFavoritesEmpty))

        default:
            stickerGrid(state: viewModel.stickersState, emptyMessage: emptyStickerMessage)
        }
    }

    private var showsSuggestionChips: Bool {
        guard options.allowsGifSelection, viewModel.isSearchActive, !viewModel.isSearchEmpty else {
            return false
        }

        if case .loaded = viewModel.stickersState, !viewModel.relatedSuggestions.isEmpty {
            return true
        }

        return !viewModel.autocompleteSuggestions.isEmpty
    }

    @ViewBuilder
    private var suggestionChips: some View {
        if case .loaded = viewModel.stickersState,
           !viewModel.relatedSuggestions.isEmpty {
            suggestionSection(
                title: languageService.text(.stickersTryAlso),
                items: viewModel.relatedSuggestions
            )
        } else if !viewModel.autocompleteSuggestions.isEmpty {
            suggestionSection(
                title: nil,
                items: viewModel.autocompleteSuggestions
            )
        }
    }

    @ViewBuilder
    private func stickerGrid(state: LoadingState<[Sticker]>, emptyMessage: String) -> some View {
        switch state {
        case .idle, .loading:
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ErrorView(message: message) {
                viewModel.retry()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let stickers):
            if stickers.isEmpty {
                EmptyStateView(
                    icon: "face.smiling",
                    title: languageService.text(.stickersNoResultsTitle),
                    message: emptyMessage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: GridLayout.spacing) {
                        ForEach(stickers) { sticker in
                            Button {
                                handleStickerSelection(sticker)
                            } label: {
                                gifThumbnail(url: sticker.previewURL ?? sticker.url)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                viewModel.loadMoreStickersIfNeeded(currentStickerId: sticker.id)
                            }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .gridCellColumns(GridLayout.columnsPerRow)
                                .padding(.vertical, SplickTheme.Spacing.sm)
                        }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func handleStickerSelection(_ sticker: Sticker) {
        guard options.allowsGifSelection else { return }
        viewModel.selectSticker(sticker)
        onSelectGif(sticker)
    }

    private func suggestionSection(title: String?, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(SplickTheme.Typography.captionBold)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            viewModel.onSuggestionTapped(item)
                        } label: {
                            Text(item)
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(SplickTheme.Colors.secondaryBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func gifThumbnail(url: URL) -> some View {
        let shape = RoundedRectangle(cornerRadius: GridLayout.cornerRadius, style: .continuous)

        return shape
            .fill(SplickTheme.Colors.secondaryBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AnimatedRemoteImage(
                    url: url,
                    contentMode: .fill,
                    maxPixelSize: RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: 88)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(SplickTheme.Colors.divider.opacity(0.4), lineWidth: 0.5)
            }
            .contentShape(shape)
    }

    private var panelTitle: String {
        switch viewModel.selectedCategory {
        case .search, .trending:
            return languageService.text(.stickersPopular)
        case .favorites:
            return languageService.text(.stickersFavorites)
        case .emoji:
            return languageService.text(.stickersEmoji)
        case .klipyPack(let category):
            return category.name
        case .customPack:
            return "Splick Custom"
        }
    }

    private var emptyStickerMessage: String {
        switch viewModel.selectedCategory {
        case .customPack:
            return "Nhóm chưa có sticker tùy chỉnh."
        default:
            return "Thử từ khóa khác hoặc kiểm tra KLIPY_API_KEY."
        }
    }
}
