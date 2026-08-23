import Foundation
import FeatureFriends
import FeatureNotification

struct FriendRequestInboxAdapter: FriendRequestInboxResponding {
    let acceptUseCase: AcceptFriendRequestUseCaseProtocol
    let rejectUseCase: RejectFriendRequestUseCaseProtocol

    func acceptIncomingRequest(requestId: UUID) async throws {
        try await acceptUseCase.execute(requestId: requestId)
    }

    func rejectIncomingRequest(requestId: UUID) async throws {
        try await rejectUseCase.execute(requestId: requestId)
    }
}
