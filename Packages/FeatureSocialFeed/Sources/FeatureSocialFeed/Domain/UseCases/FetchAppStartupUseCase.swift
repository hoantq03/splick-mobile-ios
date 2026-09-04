import Foundation

public protocol FetchAppStartupUseCaseProtocol: Sendable {
    func execute() async throws -> AppStartupData
}

public struct FetchAppStartupUseCase: FetchAppStartupUseCaseProtocol, Sendable {
    private let repository: AppStartupRepositoryProtocol

    public init(repository: AppStartupRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> AppStartupData {
        try await repository.fetchStartupData()
    }
}
