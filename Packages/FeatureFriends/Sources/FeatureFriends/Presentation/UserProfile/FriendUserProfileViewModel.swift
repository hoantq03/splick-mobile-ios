import Foundation
import Common
import SplickDomain

@MainActor
public final class FriendUserProfileViewModel: ObservableObject {
    @Published var user: UserSummary
    @Published var friendStatus: FriendRelationStatus
    @Published var stats: UserProfileStats?
    @Published var paymentProfile: PaymentProfile?
    @Published var friendPaymentNotConfigured = false
    @Published var isLoadingFriendPayment = false
    @Published var paymentProfileError: String?
    @Published var nicknameDraft = ""
    @Published var isProcessing = false
    @Published var isLoadingProfile = false
    @Published var profileError: String?
    @Published var alertMessage: String?
    @Published var showNicknameEditor = false
    @Published var showPaymentSheet = false
    @Published var showRemoveConfirm = false
    @Published var showBlockConfirm = false

    public var mode: FriendProfileMode { friendStatus.profileMode }
    public var isBotProfile: Bool { SplickBot.isBot(user.id) }

    private let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol?
    private let fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol?
    private let addFriendUseCase: AddFriendUseCaseProtocol?
    private let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol?
    private let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol?
    private let acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol?
    private let cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol?
    private let removeFriendUseCase: RemoveFriendUseCaseProtocol?
    private let setNicknameUseCase: SetFriendNicknameUseCaseProtocol?
    private let blockUserUseCase: BlockUserUseCaseProtocol?
    private let unblockUserUseCase: UnblockUserUseCaseProtocol?
    private let onRelationshipChanged: (UUID, FriendRelationStatus) -> Void

    public init(
        user: UserSummary,
        initialFriendStatus: FriendRelationStatus = .none,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol?,
        fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol? = nil,
        addFriendUseCase: AddFriendUseCaseProtocol? = nil,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol? = nil,
        fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol? = nil,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol? = nil,
        cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol? = nil,
        removeFriendUseCase: RemoveFriendUseCaseProtocol? = nil,
        setNicknameUseCase: SetFriendNicknameUseCaseProtocol? = nil,
        blockUserUseCase: BlockUserUseCaseProtocol? = nil,
        unblockUserUseCase: UnblockUserUseCaseProtocol? = nil,
        onRelationshipChanged: @escaping (UUID, FriendRelationStatus) -> Void = { _, _ in }
    ) {
        self.user = user
        self.friendStatus = initialFriendStatus
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
        self.fetchFriendPaymentProfileUseCase = fetchFriendPaymentProfileUseCase
        self.addFriendUseCase = addFriendUseCase
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
        self.fetchOutgoingFriendRequestsUseCase = fetchOutgoingFriendRequestsUseCase
        self.acceptFriendRequestUseCase = acceptFriendRequestUseCase
        self.cancelFriendRequestUseCase = cancelFriendRequestUseCase
        self.removeFriendUseCase = removeFriendUseCase
        self.setNicknameUseCase = setNicknameUseCase
        self.blockUserUseCase = blockUserUseCase
        self.unblockUserUseCase = unblockUserUseCase
        self.onRelationshipChanged = onRelationshipChanged
        self.nicknameDraft = user.displayName
    }

    func loadProfile() async {
        if SplickBot.isBot(user.id) {
            user = UserSummary(
                id: SplickBot.userId,
                username: SplickBot.username,
                displayName: SplickBot.displayName,
                avatarURL: nil
            )
            friendStatus = .none
            stats = nil
            profileError = nil
            paymentProfile = nil
            friendPaymentNotConfigured = false
            paymentProfileError = nil
            return
        }

        guard let fetchUserProfileUseCase else { return }
        isLoadingProfile = true
        profileError = nil
        defer { isLoadingProfile = false }

        do {
            let profile = try await fetchUserProfileUseCase.execute(userId: user.id)
            user = profile.user
            friendStatus = profile.friendStatus
            stats = profile.stats
            nicknameDraft = profile.user.displayName
            await loadPaymentProfileIfFriend()
        } catch {
            profileError = error.localizedDescription
        }
    }

    private func loadPaymentProfileIfFriend() async {
        paymentProfile = nil
        friendPaymentNotConfigured = false
        paymentProfileError = nil
        guard friendStatus == .friends, let fetchFriendPaymentProfileUseCase else { return }

        isLoadingFriendPayment = true
        defer { isLoadingFriendPayment = false }

        do {
            let profile = try await fetchFriendPaymentProfileUseCase.execute(userId: user.id)
            if profile.hasAnyContent {
                paymentProfile = profile
            } else {
                friendPaymentNotConfigured = true
            }
        } catch NetworkError.notFound {
            friendPaymentNotConfigured = true
        } catch {
            paymentProfileError = error.localizedDescription
        }
    }

    func addFriend() async {
        guard let addFriendUseCase, friendStatus == .none else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            _ = try await addFriendUseCase.execute(username: user.username, message: nil)
            friendStatus = .requestSent
            onRelationshipChanged(user.id, .requestSent)
            await loadProfile()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func acceptFriendRequest() async {
        guard let fetchIncomingFriendRequestsUseCase,
              let acceptFriendRequestUseCase,
              friendStatus == .requestReceived else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let incoming = try await fetchIncomingFriendRequestsUseCase.executeAll()
            guard let request = incoming.first(where: { $0.requester.id == user.id }) else {
                alertMessage = "Friend request not found."
                return
            }
            try await acceptFriendRequestUseCase.execute(requestId: request.id)
            friendStatus = .friends
            onRelationshipChanged(user.id, .friends)
            await loadProfile()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func cancelFriendRequest() async {
        guard let fetchOutgoingFriendRequestsUseCase,
              let cancelFriendRequestUseCase,
              friendStatus == .requestSent else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let outgoing = try await fetchOutgoingFriendRequestsUseCase.executeAll()
            guard let request = outgoing.first(where: { $0.addressee.id == user.id }) else {
                alertMessage = "Friend request not found."
                return
            }
            try await cancelFriendRequestUseCase.execute(requestId: request.id)
            friendStatus = .none
            onRelationshipChanged(user.id, .none)
            await loadProfile()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func removeFriend() async {
        guard let removeFriendUseCase else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await removeFriendUseCase.execute(friendUserId: user.id)
            friendStatus = .none
            onRelationshipChanged(user.id, .none)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func saveNickname() async {
        guard let setNicknameUseCase else { return }
        isProcessing = true
        defer { isProcessing = false }
        let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = trimmed.isEmpty ? nil : trimmed
        do {
            user = try await setNicknameUseCase.execute(friendUserId: user.id, nickname: nickname)
            nicknameDraft = user.displayName
            showNicknameEditor = false
            onRelationshipChanged(user.id, friendStatus)
            await loadProfile()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func blockUser() async {
        guard let blockUserUseCase else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await blockUserUseCase.execute(userId: user.id)
            friendStatus = .blocked
            onRelationshipChanged(user.id, .blocked)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func unblockUser() async {
        guard let unblockUserUseCase else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await unblockUserUseCase.execute(userId: user.id)
            friendStatus = .none
            onRelationshipChanged(user.id, .none)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
