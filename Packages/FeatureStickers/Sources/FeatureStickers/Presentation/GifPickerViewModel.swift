import Foundation
import Common
import SplickDomain

public enum StickerPickerTab: String, CaseIterable, Identifiable, Sendable {
    case klipy
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .klipy: return "KLIPY Trending"
        case .custom: return "Splick Custom"
        }
    }
}

public typealias GifPickerViewModelFactory = (UUID?) -> GifPickerViewModel

@MainActor
public final class GifPickerViewModel: ObservableObject {
    @Published public var selectedTab: StickerPickerTab = .klipy
    @Published public var searchText = ""
    @Published public var stickersState: LoadingState<[Sticker]> = .idle
    @Published public var errorMessage: String?

    @Published public var categories: [StickerCategory] = []
    @Published public var trendingTerms: [String] = []
    @Published public var autocompleteSuggestions: [String] = []
    @Published public var relatedSuggestions: [String] = []

    public let groupId: UUID?

    private let fetchStickersUseCase: FetchStickersUseCaseProtocol
    private let fetchCategoriesUseCase: FetchStickerCategoriesUseCaseProtocol
    private let fetchTrendingTermsUseCase: FetchTrendingTermsUseCaseProtocol
    private let fetchSuggestionsUseCase: FetchSuggestionsUseCaseProtocol
    private let registerShareUseCase: RegisterStickerShareUseCaseProtocol

    private var searchTask: Task<Void, Never>?

    public init(
        fetchStickersUseCase: FetchStickersUseCaseProtocol,
        fetchCategoriesUseCase: FetchStickerCategoriesUseCaseProtocol,
        fetchTrendingTermsUseCase: FetchTrendingTermsUseCaseProtocol,
        fetchSuggestionsUseCase: FetchSuggestionsUseCaseProtocol,
        registerShareUseCase: RegisterStickerShareUseCaseProtocol,
        groupId: UUID?
    ) {
        self.fetchStickersUseCase = fetchStickersUseCase
        self.fetchCategoriesUseCase = fetchCategoriesUseCase
        self.fetchTrendingTermsUseCase = fetchTrendingTermsUseCase
        self.fetchSuggestionsUseCase = fetchSuggestionsUseCase
        self.registerShareUseCase = registerShareUseCase
        self.groupId = groupId
    }

    public var showsCustomTab: Bool { groupId != nil }

    public var isSearchEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func onAppear() {
        loadStickers(immediate: true)
        loadDiscoveryMetadata()
    }

    public func onTabChanged(_ tab: StickerPickerTab) {
        selectedTab = tab
        clearSuggestionState()
        loadStickers(immediate: true)
        if tab == .klipy {
            loadDiscoveryMetadata()
        }
    }

    public func onSearchTextChanged(_ text: String) {
        searchText = text
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(AppConstants.Klipy.searchDebounceMilliseconds))
            guard !Task.isCancelled else { return }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                autocompleteSuggestions = []
                relatedSuggestions = []
                loadDiscoveryMetadata()
            } else {
                await loadAutocomplete(for: trimmed)
            }
            await loadStickers(immediate: false)
        }
    }

    public func onCategoryTapped(_ category: StickerCategory) {
        applySearchTerm(category.id)
    }

    public func onSuggestionTapped(_ term: String) {
        applySearchTerm(term)
    }

    public func onTrendingTermTapped(_ term: String) {
        applySearchTerm(term)
    }

    public func selectSticker(_ sticker: Sticker) {
        if case .klipy = sticker.source {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                await registerShareUseCase.execute(
                    gifId: sticker.id,
                    searchQuery: query.isEmpty ? nil : query
                )
            }
        }
    }

    public func retry() {
        loadStickers(immediate: true)
        if selectedTab == .klipy, isSearchEmpty {
            loadDiscoveryMetadata()
        }
    }

    private func applySearchTerm(_ term: String) {
        searchTask?.cancel()
        searchText = term
        autocompleteSuggestions = []
        relatedSuggestions = []
        loadStickers(immediate: true)
    }

    private func clearSuggestionState() {
        autocompleteSuggestions = []
        relatedSuggestions = []
        if selectedTab != .klipy {
            categories = []
            trendingTerms = []
        }
    }

    private func loadDiscoveryMetadata() {
        guard selectedTab == .klipy else { return }

        Task {
            async let categoriesResult = fetchCategoriesUseCase.execute()
            async let trendingResult = fetchTrendingTermsUseCase.execute()

            if let loadedCategories = try? await categoriesResult {
                categories = loadedCategories
            }
            if let loadedTerms = try? await trendingResult {
                trendingTerms = loadedTerms
            }
        }
    }

    private func loadAutocomplete(for query: String) async {
        guard selectedTab == .klipy else {
            autocompleteSuggestions = []
            return
        }

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
        guard selectedTab == .klipy else {
            relatedSuggestions = []
            return
        }

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

        let query = searchText
        let source = currentSource

        Task {
            do {
                if selectedTab == .custom, groupId == nil {
                    throw StickerError.groupRequired
                }
                let stickers = try await fetchStickersUseCase.execute(
                    query: query,
                    source: source
                )
                stickersState = .loaded(stickers)

                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if selectedTab == .klipy, !trimmed.isEmpty {
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

    private var currentSource: StickerSource {
        switch selectedTab {
        case .klipy:
            return .klipy
        case .custom:
            guard let groupId else {
                return .klipy
            }
            return .custom(groupId: groupId)
        }
    }
}
