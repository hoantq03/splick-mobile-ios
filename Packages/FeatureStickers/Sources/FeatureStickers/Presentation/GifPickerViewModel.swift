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
    @Published private(set) var favoriteExternalIds: Set<String> = []
    @Published private(set) var togglingFavoriteIds: Set<String> = []

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
    private let removeFavoriteStickerUseCase: RemoveFavoriteStickerUseCaseProtocol
    private let registerShareUseCase: RegisterStickerShareUseCaseProtocol

    private var searchTask: Task<Void, Never>?
    private var nextStickerPosition: String?
    private var supportsStickerPagination = true
    private var favoriteIdByExternalId: [String: UUID] = [:]

    public init(
        fetchStickersUseCase: FetchStickersUseCaseProtocol,
        fetchCategoriesUseCase: FetchStickerCategoriesUseCaseProtocol,
        fetchSuggestionsUseCase: FetchSuggestionsUseCaseProtocol,
        fetchFavoriteStickersUseCase: FetchFavoriteStickersUseCaseProtocol,
        addFavoriteStickerUseCase: AddFavoriteStickerUseCaseProtocol,
        removeFavoriteStickerUseCase: RemoveFavoriteStickerUseCaseProtocol,
        registerShareUseCase: RegisterStickerShareUseCaseProtocol,
        groupId: UUID?
    ) {
        self.fetchStickersUseCase = fetchStickersUseCase
        self.fetchCategoriesUseCase = fetchCategoriesUseCase
        self.fetchSuggestionsUseCase = fetchSuggestionsUseCase
        self.fetchFavoriteStickersUseCase = fetchFavoriteStickersUseCase
        self.addFavoriteStickerUseCase = addFavoriteStickerUseCase
        self.removeFavoriteStickerUseCase = removeFavoriteStickerUseCase
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

    public func isFavorite(_ externalId: String) -> Bool {
        favoriteExternalIds.contains(externalId)
    }

    public func isTogglingFavorite(_ externalId: String) -> Bool {
        togglingFavoriteIds.contains(externalId)
    }

    public func onAppear() {
        loadDiscoveryMetadata()
        loadStickers(immediate: true)
        refreshFavoriteIndex()
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
        Task {
            if case .klipy = sticker.source {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                await registerShareUseCase.execute(
                    gifId: sticker.id,
                    searchQuery: query.isEmpty ? nil : query
                )
            }
            await addFavoriteIfNeeded(sticker)
        }
    }

    public func toggleFavorite(_ sticker: Sticker) {
        guard !togglingFavoriteIds.contains(sticker.id) else { return }

        if isFavorite(sticker.id) {
            removeFavorite(sticker)
        } else {
            saveFavorite(sticker)
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
                applyFavoritesSnapshot(stickers)
            } catch {
                favoritesState = .failed(userFacingMessage(from: error))
                errorMessage = userFacingMessage(from: error)
            }
        }
    }

    private func refreshFavoriteIndex() {
        Task {
            do {
                let stickers = try await fetchFavoriteStickersUseCase.execute()
                syncFavoriteIndex(from: stickers)
            } catch {
                // Star state may be stale until favorites load succeeds.
            }
        }
    }

    private func saveFavorite(_ sticker: Sticker) {
        togglingFavoriteIds.insert(sticker.id)
        errorMessage = nil

        Task {
            defer { togglingFavoriteIds.remove(sticker.id) }

            do {
                let saved = try await addFavoriteStickerUseCase.execute(sticker: sticker, name: nil)
                applySavedFavorite(saved)
            } catch {
                errorMessage = userFacingMessage(from: error)
            }
        }
    }

    private func removeFavorite(_ sticker: Sticker) {
        guard let favoriteId = sticker.favoriteId ?? favoriteIdByExternalId[sticker.id] else {
            errorMessage = userFacingMessage(from: NetworkError.notFound)
            return
        }

        togglingFavoriteIds.insert(sticker.id)
        errorMessage = nil

        Task {
            defer { togglingFavoriteIds.remove(sticker.id) }

            do {
                try await removeFavoriteStickerUseCase.execute(favoriteId: favoriteId)
                unmarkFavorite(externalId: sticker.id)
            } catch {
                errorMessage = userFacingMessage(from: error)
            }
        }
    }

    private func addFavoriteIfNeeded(_ sticker: Sticker) async {
        guard !isFavorite(sticker.id) else { return }

        togglingFavoriteIds.insert(sticker.id)
        defer { togglingFavoriteIds.remove(sticker.id) }

        do {
            let saved = try await addFavoriteStickerUseCase.execute(sticker: sticker, name: nil)
            applySavedFavorite(saved)
        } catch {
            errorMessage = userFacingMessage(from: error)
        }
    }

    private func applySavedFavorite(_ saved: Sticker) {
        markFavorite(saved)
        appendToFavoritesList(saved)
    }

    private func applyFavoritesSnapshot(_ stickers: [Sticker]) {
        let unique = Self.uniqueStickers(stickers)
        syncFavoriteIndex(from: unique)
        favoritesState = .loaded(unique)
    }

    private func syncFavoriteIndex(from stickers: [Sticker]) {
        favoriteExternalIds = Set(stickers.map(\.id))
        favoriteIdByExternalId = Dictionary(
            stickers.compactMap { sticker -> (String, UUID)? in
                guard let favoriteId = sticker.favoriteId else { return nil }
                return (sticker.id, favoriteId)
            },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    private func markFavorite(_ sticker: Sticker) {
        favoriteExternalIds.insert(sticker.id)
        if let favoriteId = sticker.favoriteId {
            favoriteIdByExternalId[sticker.id] = favoriteId
        }
    }

    private func unmarkFavorite(externalId: String) {
        favoriteExternalIds.remove(externalId)
        favoriteIdByExternalId.removeValue(forKey: externalId)
        if case .loaded(let stickers) = favoritesState {
            let filtered = stickers.filter { $0.id != externalId }
            favoritesState = .loaded(filtered)
        }
    }

    private func appendToFavoritesList(_ sticker: Sticker) {
        switch favoritesState {
        case .loaded(let stickers):
            guard !stickers.contains(where: { $0.id == sticker.id }) else { return }
            favoritesState = .loaded([sticker] + stickers)
        case .idle, .failed:
            favoritesState = .loaded([sticker])
        case .loading:
            break
        }
    }

    private func userFacingMessage(from error: Error) -> String {
        if let networkError = error as? NetworkError {
            return networkError.userMessage
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
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
                stickersState = .loaded(Self.uniqueStickers(page.stickers))
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
                stickersState = .failed(userFacingMessage(from: error))
                errorMessage = userFacingMessage(from: error)
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
                stickersState = .loaded(Self.mergeUniqueStickers(currentStickers, page.stickers))
                nextStickerPosition = page.nextPosition
            } catch {
                // Keep existing results if pagination fails.
            }
        }
    }

    /// KLIPY pagination can overlap page boundaries; SwiftUI ForEach requires unique `Sticker.id`.
    private static func uniqueStickers(_ stickers: [Sticker]) -> [Sticker] {
        mergeUniqueStickers([], stickers)
    }

    private static func mergeUniqueStickers(_ existing: [Sticker], _ incoming: [Sticker]) -> [Sticker] {
        var seen = Set(existing.map(\.id))
        var merged = existing
        for sticker in incoming where seen.insert(sticker.id).inserted {
            merged.append(sticker)
        }
        return merged
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
