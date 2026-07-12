import Foundation
import Common
import SplickDomain

public typealias GifPickerViewModelFactory = (UUID?) -> GifPickerViewModel

@MainActor
public final class GifPickerViewModel: ObservableObject {
    @Published public var selectedCategory: AttachmentPickerCategory = .trending
    @Published public var isSearchActive = false
    @Published public var searchText = ""
    @Published public var stickersState: LoadingState<[Sticker]> = .idle
    @Published public var favoritesState: LoadingState<[Sticker]> = .idle
    @Published public var errorMessage: String?

    @Published public var categories: [StickerCategory] = []
    @Published public var autocompleteSuggestions: [String] = []
    @Published public var relatedSuggestions: [String] = []
    @Published public var isLoadingMore = false

    public let groupId: UUID?

    private let fetchStickersUseCase: FetchStickersUseCaseProtocol
    private let fetchCategoriesUseCase: FetchStickerCategoriesUseCaseProtocol
    private let fetchSuggestionsUseCase: FetchSuggestionsUseCaseProtocol
    private let fetchFavoriteStickersUseCase: FetchFavoriteStickersUseCaseProtocol
    private let addFavoriteStickerUseCase: AddFavoriteStickerUseCaseProtocol
    private let registerShareUseCase: RegisterStickerShareUseCaseProtocol

    private var searchTask: Task<Void, Never>?
    private var nextStickerPosition: String?
    private var supportsStickerPagination = true

    public init(
        fetchStickersUseCase: FetchStickersUseCaseProtocol,
        fetchCategoriesUseCase: FetchStickerCategoriesUseCaseProtocol,
        fetchSuggestionsUseCase: FetchSuggestionsUseCaseProtocol,
        fetchFavoriteStickersUseCase: FetchFavoriteStickersUseCaseProtocol,
        addFavoriteStickerUseCase: AddFavoriteStickerUseCaseProtocol,
        registerShareUseCase: RegisterStickerShareUseCaseProtocol,
        groupId: UUID?
    ) {
        self.fetchStickersUseCase = fetchStickersUseCase
        self.fetchCategoriesUseCase = fetchCategoriesUseCase
        self.fetchSuggestionsUseCase = fetchSuggestionsUseCase
        self.fetchFavoriteStickersUseCase = fetchFavoriteStickersUseCase
        self.addFavoriteStickerUseCase = addFavoriteStickerUseCase
        self.registerShareUseCase = registerShareUseCase
        self.groupId = groupId
    }

    public var showsCustomPack: Bool { groupId != nil }

    public var isSearchEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var showsStickerContent: Bool {
        selectedCategory != .emoji
    }

    public func onAppear() {
        loadDiscoveryMetadata()
        loadStickers(immediate: true)
    }

    public func onCategorySelected(_ category: AttachmentPickerCategory) {
        switch category {
        case .search:
            isSearchActive.toggle()
            if isSearchActive {
                selectedCategory = .trending
            }
            return
        case .emoji:
            selectedCategory = .emoji
            isSearchActive = false
            return
        case .favorites:
            selectedCategory = .favorites
            isSearchActive = false
            loadFavorites()
            return
        case .trending:
            selectedCategory = .trending
            isSearchActive = false
            searchText = ""
            autocompleteSuggestions = []
            relatedSuggestions = []
            loadStickers(immediate: true)
            return
        case .klipyPack(let stickerCategory):
            selectedCategory = .klipyPack(stickerCategory)
            isSearchActive = false
            applySearchTerm(stickerCategory.id)
            return
        case .customPack:
            selectedCategory = .customPack
            isSearchActive = false
            searchText = ""
            autocompleteSuggestions = []
            relatedSuggestions = []
            loadStickers(immediate: true)
            return
        }
    }

    public func onSearchTextChanged(_ text: String) {
        searchText = text
        isSearchActive = true
        selectedCategory = .trending

        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(AppConstants.Klipy.searchDebounceMilliseconds))
            guard !Task.isCancelled else { return }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                autocompleteSuggestions = []
                relatedSuggestions = []
            } else {
                await loadAutocomplete(for: trimmed)
            }
            await loadStickers(immediate: false)
        }
    }

    public func onSuggestionTapped(_ term: String) {
        applySearchTerm(term)
        isSearchActive = true
    }

    public func selectSticker(_ sticker: Sticker) {
        if case .klipy = sticker.source {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                await registerShareUseCase.execute(
                    gifId: sticker.id,
                    searchQuery: query.isEmpty ? nil : query
                )
                try? await addFavoriteStickerUseCase.execute(sticker: sticker, name: nil)
            }
        }
    }

    public func loadMoreStickersIfNeeded(currentStickerId: String) {
        guard supportsStickerPagination,
              let nextPosition = nextStickerPosition,
              !nextPosition.isEmpty,
              !isLoadingMore,
              case .loaded(let stickers) = stickersState,
              stickers.last?.id == currentStickerId else {
            return
        }
        loadMoreStickers()
    }

    public func retry() {
        switch selectedCategory {
        case .favorites:
            loadFavorites()
        case .emoji:
            break
        default:
            loadStickers(immediate: true)
            if isSearchEmpty {
                loadDiscoveryMetadata()
            }
        }
    }

    private func applySearchTerm(_ term: String) {
        searchTask?.cancel()
        searchText = term
        autocompleteSuggestions = []
        relatedSuggestions = []
        loadStickers(immediate: true)
    }

    private func loadDiscoveryMetadata() {
        Task {
            if let loadedCategories = try? await fetchCategoriesUseCase.execute() {
                categories = loadedCategories
            }
        }
    }

    private func loadFavorites() {
        favoritesState = .loading
        errorMessage = nil

        Task {
            do {
                let stickers = try await fetchFavoriteStickersUseCase.execute()
                favoritesState = .loaded(stickers)
            } catch {
                favoritesState = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadAutocomplete(for query: String) async {
        if let suggestions = try? await fetchSuggestionsUseCase.execute(
            query: query,
            type: .autocomplete
        ) {
            autocompleteSuggestions = suggestions
        } else {
            autocompleteSuggestions = []
        }
    }

    private func loadRelatedSuggestions(for query: String) async {
        if let suggestions = try? await fetchSuggestionsUseCase.execute(
            query: query,
            type: .searchSuggestions
        ) {
            relatedSuggestions = suggestions
        } else {
            relatedSuggestions = []
        }
    }

    private func loadStickers(immediate: Bool) {
        if immediate {
            searchTask?.cancel()
        }

        stickersState = .loading
        errorMessage = nil
        isLoadingMore = false
        nextStickerPosition = nil
        supportsStickerPagination = selectedCategory != .customPack

        let query = searchText
        let source = currentSource

        Task {
            do {
                if selectedCategory == .customPack, groupId == nil {
                    throw StickerError.groupRequired
                }
                let page = try await fetchStickersUseCase.execute(
                    query: query,
                    source: source,
                    position: nil
                )
                stickersState = .loaded(page.stickers)
                nextStickerPosition = page.nextPosition

                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if selectedCategory != .customPack, !trimmed.isEmpty {
                    await loadRelatedSuggestions(for: trimmed)
                } else {
                    relatedSuggestions = []
                }
            } catch let error as StickerError {
                stickersState = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            } catch {
                stickersState = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadMoreStickers() {
        guard supportsStickerPagination,
              let position = nextStickerPosition,
              !position.isEmpty,
              !isLoadingMore,
              case .loaded(let currentStickers) = stickersState else {
            return
        }

        isLoadingMore = true
        let query = searchText
        let source = currentSource

        Task {
            defer { isLoadingMore = false }

            do {
                let page = try await fetchStickersUseCase.execute(
                    query: query,
                    source: source,
                    position: position
                )
                let merged = currentStickers + page.stickers
                stickersState = .loaded(merged)
                nextStickerPosition = page.nextPosition
            } catch {
                // Keep existing results if pagination fails.
            }
        }
    }

    private var currentSource: StickerSource {
        switch selectedCategory {
        case .customPack:
            guard let groupId else {
                return .klipy
            }
            return .custom(groupId: groupId)
        default:
            return .klipy
        }
    }
}
