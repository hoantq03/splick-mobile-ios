import Foundation
import SplickDomain

public protocol FetchStreakUseCaseProtocol: Sendable {
    func fetchSummary() async throws -> StreakSummary
    func fetchCalendar(year: Int, month: Int) async throws -> [StreakDay]
    func fetchDayPhotos(date: String) async throws -> [AlbumPhoto]
}

public final class FetchStreakUseCase: FetchStreakUseCaseProtocol {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func fetchSummary() async throws -> StreakSummary {
        try await repository.fetchStreakSummary()
    }

    public func fetchCalendar(year: Int, month: Int) async throws -> [StreakDay] {
        try await repository.fetchStreakCalendar(year: year, month: month)
    }

    public func fetchDayPhotos(date: String) async throws -> [AlbumPhoto] {
        try await repository.fetchStreakDayPhotos(date: date)
    }
}
