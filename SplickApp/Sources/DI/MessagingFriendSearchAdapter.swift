import Foundation
import FeatureFriends
import FeatureMessaging
import SplickDomain

struct MessagingFriendSearchAdapter: MessagingFriendSearchProviding {
    private let searchUsersUseCase: SearchUsersUseCaseProtocol

    init(searchUsersUseCase: SearchUsersUseCaseProtocol) {
        self.searchUsersUseCase = searchUsersUseCase
    }

    func searchFriends(query: String) async throws -> [UserSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let results = try await searchUsersUseCase.execute(query: trimmed, page: 0, size: 20)
        return results
            .filter { $0.friendStatus == .friends }
            .map(\.user)
    }
}
