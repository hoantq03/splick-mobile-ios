import Foundation
import SplickDomain

public final class KlipyMetaRepositoryImpl: KlipyMetaRepositoryProtocol, Sendable {
    private let klipyDataSource: KlipyDataSourceProtocol

    public init(klipyDataSource: KlipyDataSourceProtocol = KlipyDataSource()) {
        self.klipyDataSource = klipyDataSource
    }

    public func fetchCategories() async throws -> [StickerCategory] {
        try await klipyDataSource.categories()
    }

    public func fetchAutocomplete(query: String) async throws -> [String] {
        try await klipyDataSource.autocomplete(query: query)
    }

    public func fetchSearchSuggestions(query: String) async throws -> [String] {
        try await klipyDataSource.searchSuggestions(query: query)
    }

    public func fetchTrendingTerms() async throws -> [String] {
        try await klipyDataSource.trendingTerms()
    }

    public func registerShare(gifId: String, searchQuery: String?) async throws {
        try await klipyDataSource.registerShare(gifId: gifId, searchQuery: searchQuery)
    }
}
