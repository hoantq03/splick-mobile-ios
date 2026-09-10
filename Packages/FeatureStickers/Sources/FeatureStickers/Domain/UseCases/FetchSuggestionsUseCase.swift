import Foundation

public enum KlipySuggestionType: Sendable {
    case autocomplete
    case searchSuggestions
}

public protocol FetchSuggestionsUseCaseProtocol: Sendable {
    func execute(query: String, type: KlipySuggestionType) async throws -> [String]
}

public final class FetchSuggestionsUseCase: FetchSuggestionsUseCaseProtocol, Sendable {
    private let repository: KlipyMetaRepositoryProtocol

    public init(repository: KlipyMetaRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(query: String, type: KlipySuggestionType) async throws -> [String] {
        switch type {
        case .autocomplete:
            return try await repository.fetchAutocomplete(query: query)
        case .searchSuggestions:
            return try await repository.fetchSearchSuggestions(query: query)
        }
    }
}
