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
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoadingPosts = false
    @Published private(set) var isLoadingMorePosts = false
    @Published private(set) var postsError: String?
    @Published private(set) var profileIsOnline = false
    @Published private(set) var profileLastSeenAt: Date?

    public var mode: FriendProfileMode { friendStatus.profileMode }
    public var isBotProfile: Bool { SplickBot.isBot(user.id) }
    public var isOwnProfile: Bool { user.id == currentUserId }
    public var canLoadMorePosts: Bool { hasMorePosts && !isLoadingMorePosts }

    private static let postsPageSize = 20
    private let currentUserId: UUID?
    private let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol?
    private let fetchUserPostsUseCase: FetchUserPostsUseCaseProtocol?
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
    private let onFriendSummaryUpdated: (UserSummary) -> Void
    private var postsPage = 0
    private var hasMorePosts = true

    public init(
        user: UserSummary,
        currentUserId: UUID? = nil,
        initialFriendStatus: FriendRelationStatus = .none,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol?,
        fetchUserPostsUseCase: FetchUserPostsUseCaseProtocol? = nil,
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
        onRelationshipChanged: @escaping (UUID, FriendRelationStatus) -> Void = { _, _ in },
        onFriendSummaryUpdated: @escaping (UserSummary) -> Void = { _ in }
    ) {
        self.user = user
        self.currentUserId = currentUserId
        self.friendStatus = initialFriendStatus
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
        self.fetchUserPostsUseCase = fetchUserPostsUseCase
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
        self.onFriendSummaryUpdated = onFriendSummaryUpdated
        self.nicknameDraft = user.displayName
    }

    func loadPostsIfNeeded() async {
        guard posts.isEmpty, postsError == nil else { return }
        await refreshPosts()
    }

    func refreshPosts() async {
        guard !isBotProfile, let fetchUserPostsUseCase else { return }
        isLoadingPosts = true
        postsError = nil
        defer { isLoadingPosts = false }

        do {
            let firstPage = try await fetchUserPostsUseCase.execute(authorId: user.id, page: 0)
            guard !Task.isCancelled else { return }
            posts = firstPage
            postsPage = 0
            hasMorePosts = firstPage.count == Self.postsPageSize
        } catch {
            guard !error.isRequestCancellation else { return }
            postsError = error.localizedDescription
        }
    }

    func loadMorePostsIfNeeded(currentPostId: UUID) async {
        guard currentPostId == posts.last?.id,
              canLoadMorePosts,
              let fetchUserPostsUseCase else { return }

        isLoadingMorePosts = true
        postsError = nil
        defer { isLoadingMorePosts = false }

        do {
            let nextPageIndex = postsPage + 1
            let nextPage = try await fetchUserPostsUseCase.execute(
                authorId: user.id,
                page: nextPageIndex
            )
            guard !Task.isCancelled else { return }
            let existingIds = Set(posts.map(\.id))
            posts.append(contentsOf: nextPage.filter { !existingIds.contains($0.id) })
            postsPage = nextPageIndex
            hasMorePosts = nextPage.count == Self.postsPageSize
        } catch {
            guard !error.isRequestCancellation else { return }
            postsError = error.localizedDescription
        }
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
            profileIsOnline = false
            profileLastSeenAt = nil
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
            guard !Task.isCancelled else { return }
            user = profile.user
            friendStatus = profile.friendStatus
            stats = profile.stats
            profileIsOnline = profile.isOnline
            profileLastSeenAt = profile.lastSeenAt
            nicknameDraft = profile.user.displayName
            await loadPaymentProfileIfFriend()
        } catch {
            // Pull-to-refresh / overlapping `.task` cancels in-flight loads — not a user-facing failure.
            guard !error.isRequestCancellation else { return }
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
            guard !Task.isCancelled else { return }
            if profile.hasAnyContent {
                paymentProfile = profile
            } else {
                friendPaymentNotConfigured = true
            }
        } catch NetworkError.notFound {
            friendPaymentNotConfigured = true
        } catch {
            guard !error.isRequestCancellation else { return }
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
            onFriendSummaryUpdated(user)
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
