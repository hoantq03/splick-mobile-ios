import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain

public struct AttachmentPickerView: View {
    @ObservedObject private var viewModel: GifPickerViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.currentUserSummary) private var currentUserSummary

    private let options: AttachmentPickerOptions
    private let currentUserId: UUID?
    private let onSelectGif: (Sticker) -> Void
    private let onSelectEmoji: (String) -> Void

    @State private var peekedSticker: Sticker?

    private var resolvedUserId: UUID? {
        currentUserId ?? currentUserSummary?.id
    }

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
            .padding(.top, SplickTheme.Spacing.sm)
            .padding(.bottom, SplickTheme.Spacing.xs)

            if viewModel.isSearchActive, options.allowsGifSelection {
                searchBar
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.bottom, SplickTheme.Spacing.xs)
            }

            VStack(spacing: SplickTheme.Spacing.xs) {
                AttachmentPickerPanelHeader(title: panelTitle)
                    .padding(.horizontal, SplickTheme.Spacing.md)

                if let errorMessage = viewModel.errorMessage {
                    favoriteErrorBanner(message: errorMessage)
                        .padding(.horizontal, SplickTheme.Spacing.md)
                }

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
        .overlay {
            if let peekedSticker {
                StickerGifPeekOverlay(
                    sticker: peekedSticker,
                    isFavorite: viewModel.isFavorite(peekedSticker.id),
                    isTogglingFavorite: viewModel.isTogglingFavorite(peekedSticker.id),
                    addFavoriteTitle: languageService.text(.stickersAddFavorite),
                    removeFavoriteTitle: languageService.text(.stickersRemoveFavorite),
                    onToggleFavorite: {
                        viewModel.toggleFavorite(peekedSticker)
                    },
                    onDismiss: {
                        self.peekedSticker = nil
                    },
                    onSelect: {
                        let sticker = peekedSticker
                        self.peekedSticker = nil
                        handleStickerSelection(sticker)
                    }
                )
                .zIndex(10)
            }
        }
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
                    currentUserId: resolvedUserId,
                    searchQuery: viewModel.searchText,
                    onPick: onSelectEmoji
                )
                .padding(.horizontal, SplickTheme.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .favorites:
            stickerGrid(
                state: viewModel.favoritesState,
                emptyMessage: languageService.text(.stickersFavoritesEmpty)
            )

        default:
            stickerGrid(
                state: viewModel.stickersState,
                emptyMessage: emptyStickerMessage
            )
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
    private func stickerGrid(
        state: LoadingState<[Sticker]>,
        emptyMessage: String
    ) -> some View {
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
                            stickerCell(sticker: sticker)
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

    @ViewBuilder
    private func stickerCell(sticker: Sticker) -> some View {
        StickerGifGridCell(
            sticker: sticker,
            allowsPeek: options.allowsGifSelection,
            isPeeking: peekedSticker?.id == sticker.id,
            thumbnail: { gifThumbnail(url: sticker.previewURL ?? sticker.url) },
            onSelect: { handleStickerSelection(sticker) },
            onPeek: {
                peekedSticker = sticker
            }
        )
    }

    private func favoriteErrorBanner(message: String) -> some View {
        Text(message)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(SplickTheme.Colors.error.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
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
        let maxPixelSize = RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: 88)

        return shape
            .fill(SplickTheme.Colors.secondaryBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                // Still frames only — animating every grid cell spikes CPU hard.
                RemoteImage(url: url, maxPixelSize: maxPixelSize) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.clear
                    }
                }
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
            return languageService.text(.stickersSplickCustom)
        }
    }

    private var emptyStickerMessage: String {
        switch viewModel.selectedCategory {
        case .customPack:
            return languageService.text(.stickersGroupCustomEmpty)
        default:
            return languageService.text(.stickersSearchFailedHint)
        }
    }
}

// MARK: - Grid cell with iOS-like press → peek

private enum StickerGifPressMetrics {
    /// Matches UILongPressGestureRecognizer default feel.
    static let duration: Double = 0.5
    /// Subtle grow while finger is down (before the pop).
    static let highlightScale: CGFloat = 1.1
    static let maximumDistance: CGFloat = 14
    static let peekImpact = UIImpactFeedbackGenerator(style: .rigid)
}

private struct StickerGifGridCell<Thumbnail: View>: View {
    let sticker: Sticker
    let allowsPeek: Bool
    let isPeeking: Bool
    let thumbnail: () -> Thumbnail
    let onSelect: () -> Void
    let onPeek: () -> Void

    @State private var isPressing = false
    @State private var didTriggerPeek = false

    var body: some View {
        thumbnail()
            .contentShape(
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.tile, style: .continuous)
            )
            .scaleEffect(cellScale)
            .shadow(
                color: .black.opacity(isPressing && !isPeeking ? 0.22 : 0),
                radius: isPressing && !isPeeking ? 10 : 0,
                y: isPressing && !isPeeking ? 6 : 0
            )
            .zIndex(isPressing || isPeeking ? 2 : 0)
            .opacity(isPeeking ? 0 : 1)
            .animation(.easeOut(duration: 0.12), value: isPeeking)
            .onTapGesture(perform: onSelect)
            .onLongPressGesture(
                minimumDuration: StickerGifPressMetrics.duration,
                maximumDistance: StickerGifPressMetrics.maximumDistance,
                pressing: handlePressing(_:),
                perform: handlePeekTriggered
            )
            .onChange(of: isPeeking) { peeking in
                if !peeking {
                    didTriggerPeek = false
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isPressing = false
                    }
                }
            }
    }

    private var cellScale: CGFloat {
        if isPeeking { return StickerGifPressMetrics.highlightScale }
        return isPressing ? StickerGifPressMetrics.highlightScale : 1
    }

    private func handlePressing(_ pressing: Bool) {
        guard allowsPeek else { return }

        if pressing {
            didTriggerPeek = false
            StickerGifPressMetrics.peekImpact.prepare()
            // Gradual grow while holding — duration matches long-press threshold.
            withAnimation(.easeIn(duration: StickerGifPressMetrics.duration)) {
                isPressing = true
            }
            return
        }

        // Finger lifted before threshold, or after peek already opened.
        if !didTriggerPeek {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isPressing = false
            }
        }
    }

    private func handlePeekTriggered() {
        guard allowsPeek else { return }
        didTriggerPeek = true
        StickerGifPressMetrics.peekImpact.impactOccurred(intensity: 1.0)
        onPeek()
    }
}


