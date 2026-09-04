import Foundation

public protocol FetchTrendingTermsUseCaseProtocol: Sendable {
    func execute() async throws -> [String]
}

public final class FetchTrendingTermsUseCase: FetchTrendingTermsUseCaseProtocol, Sendable {
    private let repository: KlipyMetaRepositoryProtocol

    public init(repository: KlipyMetaRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [String] {
        try await repository.fetchTrendingTerms()
    }
}
