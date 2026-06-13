import Foundation
import SplickDomain
import FeatureFriends
import FeatureMessaging

struct FetchMyFriendsAdapter: FriendsListProviding {
    private let useCase: FetchMyFriendsUseCaseProtocol

    init(useCase: FetchMyFriendsUseCaseProtocol) {
        self.useCase = useCase
    }

    func fetchFriends() async throws -> [UserSummary] {
        try await useCase.execute()
    }
}
