import Foundation
import SplickDomain

public protocol KlipyMetaRepositoryProtocol: Sendable {
    func fetchCategories() async throws -> [StickerCategory]
    func fetchAutocomplete(query: String) async throws -> [String]
    func fetchSearchSuggestions(query: String) async throws -> [String]
    func fetchTrendingTerms() async throws -> [String]
    func registerShare(gifId: String, searchQuery: String?) async throws
}
