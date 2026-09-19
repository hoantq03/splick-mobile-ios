import Foundation
import FeatureFriends
import FeatureNotification
import SplickDomain

struct FriendRequestInboxAdapter: FriendRequestInboxResponding {
    let acceptUseCase: AcceptFriendRequestUseCaseProtocol
    let rejectUseCase: RejectFriendRequestUseCaseProtocol
    let fetchIncomingUseCase: FetchIncomingFriendRequestsUseCaseProtocol

    func acceptIncomingRequest(requestId: UUID) async throws {
        try await acceptUseCase.execute(requestId: requestId)
    }

    func rejectIncomingRequest(requestId: UUID) async throws {
        try await rejectUseCase.execute(requestId: requestId)
    }

    func pendingIncomingRequests() async throws -> PendingIncomingFriendRequests {
        let incoming = try await fetchIncomingUseCase.executeAll()
        let byRequester = Dictionary(
            incoming.map { ($0.requester.id, $0.id) },
            uniquingKeysWith: { _, last in last }
        )
        return PendingIncomingFriendRequests(requestIdByRequester: byRequester)
    }
}
