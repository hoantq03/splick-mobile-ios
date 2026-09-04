import Foundation
import FeatureFriends
import FeatureMessaging

struct MessagingSearchAdapter: MessagingSearchProviding {
    private static let minMessageQueryLength = 2

    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let messagingRepository: MessagingRepositoryProtocol

    init(
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        messagingRepository: MessagingRepositoryProtocol
    ) {
        self.searchUsersUseCase = searchUsersUseCase
        self.messagingRepository = messagingRepository
    }

    func search(query: String) async throws -> [MessagingSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        async let userResults = searchUsersUseCase.execute(query: trimmed, page: 0, size: 20)
        async let messageResults: [MessageSearchHit] = {
            guard trimmed.count >= Self.minMessageQueryLength else { return [] }
            return (try? await messagingRepository.searchMessages(query: trimmed, page: 0, limit: 20)) ?? []
        }()

        let users = try await userResults.map { MessagingSearchResult.user($0.user) }
        let messages = await messageResults.map { MessagingSearchResult.message($0) }
        return users + messages
    }
}
