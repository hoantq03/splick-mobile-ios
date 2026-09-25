import Foundation
import Common
import Networking
import SplickDomain
import SwiftUI

public typealias GifKeywordSuggestControllerFactory = () -> GifKeywordSuggestController

public struct GifKeywordSuggestFactoryKey: EnvironmentKey {
    public static let defaultValue: GifKeywordSuggestControllerFactory? = nil
}

public extension EnvironmentValues {
    var gifKeywordSuggestFactory: GifKeywordSuggestControllerFactory? {
        get { self[GifKeywordSuggestFactoryKey.self] }
        set { self[GifKeywordSuggestFactoryKey.self] = newValue }
    }
}

@MainActor
public final class GifKeywordSuggestController: ObservableObject {
    public static let resultCap = 8

    @Published public private(set) var stickers: [Sticker] = []
    @Published public private(set) var keyword: String?

    private let fetchStickersUseCase: FetchStickersUseCaseProtocol
    private let searchHistory: SearchHistorySession?
    private let debounceNanoseconds: UInt64
    private var suggestTask: Task<Void, Never>?
    private var dismissedKeyword: String?
    private var searchCountForTests = 0

    public init(
        fetchStickersUseCase: FetchStickersUseCaseProtocol,
        searchHistoryRepository: SearchHistoryRepositoryProtocol? = nil,
        debounceMilliseconds: Int = AppConstants.Klipy.searchDebounceMilliseconds
    ) {
        self.fetchStickersUseCase = fetchStickersUseCase
        self.searchHistory = searchHistoryRepository.map {
            SearchHistorySession(repository: $0, scope: .gif)
        }
        self.debounceNanoseconds = UInt64(max(0, debounceMilliseconds)) * 1_000_000
    }

    public var testSearchCount: Int { searchCountForTests }

    public func onDraftChanged(
        _ draft: String,
        cursor: Int? = nil,
        mentionActive: Bool = false
    ) {
        let next = GifKeywordDetector.keyword(
            in: draft,
            cursor: cursor,
            mentionActive: mentionActive
        )
        guard let next else {
            clearVisibleSuggestions()
            return
        }
        if next == dismissedKeyword {
            return
        }
        if next != dismissedKeyword {
            dismissedKeyword = nil
        }
        if next == keyword, !stickers.isEmpty {
            return
        }
        suggestForKeyword(next)
    }

    public func suggestForKeyword(_ keyword: String?) {
        suggestTask?.cancel()
        guard let keyword, !keyword.isEmpty else {
            clearVisibleSuggestions()
            return
        }
        self.keyword = keyword
        suggestTask = Task { [debounceNanoseconds] in
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await self.search(keyword)
        }
    }

    public func dismiss() {
        dismissedKeyword = keyword
        clearVisibleSuggestions()
    }

    public func recordSelection() {
        if let keyword {
            searchHistory?.record(keyword)
        }
        dismissedKeyword = keyword
        clearVisibleSuggestions()
    }

    private func search(_ keyword: String) async {
        searchCountForTests += 1
        do {
            let page = try await fetchStickersUseCase.execute(
                query: keyword,
                source: .klipy,
                position: nil
            )
            guard !Task.isCancelled else { return }
            guard self.keyword == keyword else { return }
            stickers = Array(page.stickers.prefix(Self.resultCap))
        } catch {
            guard self.keyword == keyword else { return }
            stickers = []
        }
    }

    private func clearVisibleSuggestions() {
        suggestTask?.cancel()
        suggestTask = nil
        stickers = []
        keyword = nil
    }
}
