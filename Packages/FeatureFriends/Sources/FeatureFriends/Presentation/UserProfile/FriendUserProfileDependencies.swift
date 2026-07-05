import Foundation
import SplickDomain

public struct FriendUserProfileDependencies {
    public let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    public let fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol
    public let addFriendUseCase: AddFriendUseCaseProtocol
    public let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    public let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    public let acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol
    public let cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol
    public let removeFriendUseCase: RemoveFriendUseCaseProtocol
    public let setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol
    public let blockUserUseCase: BlockUserUseCaseProtocol
    public let unblockUserUseCase: UnblockUserUseCaseProtocol

    public init(
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol,
        fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol,
        cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol,
        removeFriendUseCase: RemoveFriendUseCaseProtocol,
        setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol,
        blockUserUseCase: BlockUserUseCaseProtocol,
        unblockUserUseCase: UnblockUserUseCaseProtocol
    ) {
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
        self.fetchFriendPaymentProfileUseCase = fetchFriendPaymentProfileUseCase
        self.addFriendUseCase = addFriendUseCase
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
        self.fetchOutgoingFriendRequestsUseCase = fetchOutgoingFriendRequestsUseCase
        self.acceptFriendRequestUseCase = acceptFriendRequestUseCase
        self.cancelFriendRequestUseCase = cancelFriendRequestUseCase
        self.removeFriendUseCase = removeFriendUseCase
        self.setFriendNicknameUseCase = setFriendNicknameUseCase
        self.blockUserUseCase = blockUserUseCase
        self.unblockUserUseCase = unblockUserUseCase
    }

    @MainActor
    public func makeViewModel(
        user: UserSummary,
        initialFriendStatus: FriendRelationStatus = .none,
        onRelationshipChanged: @escaping (UUID, FriendRelationStatus) -> Void = { _, _ in }
    ) -> FriendUserProfileViewModel {
        FriendUserProfileViewModel(
            user: user,
            initialFriendStatus: initialFriendStatus,
            fetchUserProfileUseCase: fetchUserProfileUseCase,
            fetchFriendPaymentProfileUseCase: fetchFriendPaymentProfileUseCase,
            addFriendUseCase: addFriendUseCase,
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
            fetchOutgoingFriendRequestsUseCase: fetchOutgoingFriendRequestsUseCase,
            acceptFriendRequestUseCase: acceptFriendRequestUseCase,
            cancelFriendRequestUseCase: cancelFriendRequestUseCase,
            removeFriendUseCase: removeFriendUseCase,
            setNicknameUseCase: setFriendNicknameUseCase,
            blockUserUseCase: blockUserUseCase,
            unblockUserUseCase: unblockUserUseCase,
            onRelationshipChanged: onRelationshipChanged
        )
    }
}
