import Foundation
import SplickDomain

public struct FriendUserProfileDependencies {
    public let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    public let fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol
    public let addFriendUseCase: AddFriendUseCaseProtocol
    public let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    public let acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol
    public let removeFriendUseCase: RemoveFriendUseCaseProtocol
    public let setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol
    public let blockUserUseCase: BlockUserUseCaseProtocol
    public let unblockUserUseCase: UnblockUserUseCaseProtocol

    public init(
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol,
        fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol,
        removeFriendUseCase: RemoveFriendUseCaseProtocol,
        setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol,
        blockUserUseCase: BlockUserUseCaseProtocol,
        unblockUserUseCase: UnblockUserUseCaseProtocol
    ) {
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
        self.fetchFriendPaymentProfileUseCase = fetchFriendPaymentProfileUseCase
        self.addFriendUseCase = addFriendUseCase
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
        self.acceptFriendRequestUseCase = acceptFriendRequestUseCase
        self.removeFriendUseCase = removeFriendUseCase
        self.setFriendNicknameUseCase = setFriendNicknameUseCase
        self.blockUserUseCase = blockUserUseCase
        self.unblockUserUseCase = unblockUserUseCase
    }

    @MainActor
    public func makeViewModel(
        user: UserSummary,
        initialFriendStatus: FriendRelationStatus = .none,
        onRelationshipChanged: @escaping () -> Void = {}
    ) -> FriendUserProfileViewModel {
        FriendUserProfileViewModel(
            user: user,
            initialFriendStatus: initialFriendStatus,
            fetchUserProfileUseCase: fetchUserProfileUseCase,
            fetchFriendPaymentProfileUseCase: fetchFriendPaymentProfileUseCase,
            addFriendUseCase: addFriendUseCase,
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
            acceptFriendRequestUseCase: acceptFriendRequestUseCase,
            removeFriendUseCase: removeFriendUseCase,
            setNicknameUseCase: setFriendNicknameUseCase,
            blockUserUseCase: blockUserUseCase,
            unblockUserUseCase: unblockUserUseCase,
            onRelationshipChanged: onRelationshipChanged
        )
    }
}
