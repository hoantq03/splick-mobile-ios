import Foundation

public protocol FetchBadgeCountsUseCaseProtocol: Sendable {
    func execute() async throws -> TabBadgeCounts
}

public final class FetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol, Sendable {
    private let repository: NotificationRepositoryProtocol

    public init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> TabBadgeCounts {
        try await repository.fetchBadgeCounts()
    }
}
