import FeatureFriends
import FeatureMessaging
import SplickDomain

struct InboxFriendsAdapter: InboxFriendsProviding {
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol

    init(fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol) {
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
    }

    func fetchFriends() async throws -> [UserSummary] {
        try await fetchMyFriendsUseCase.execute()
    }
}
