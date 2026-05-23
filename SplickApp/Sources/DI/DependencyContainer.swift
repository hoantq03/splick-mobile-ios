import Foundation
import Networking
import Storage
import Common
import SplickDomain
import FeatureAuth
import FeatureSocialFeed
import FeatureMedia
import FeatureExpense
import FeatureNotification
import FeatureFriends
import SimulationKit

@MainActor
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()

    // MARK: - Core

    let tokenProvider: TokenProvider
    let keychainService: KeychainServiceProtocol
    let userDefaultsService: UserDefaultsServiceProtocol
    private let simulation: SimulationContainer?

    let apiClient: APIClientProtocol
    let sessionManager: SessionManagerProtocol

    // MARK: - Auth (always live API)

    private let authRepository: AuthRepositoryProtocol
    let refreshTokenUseCase: RefreshTokenUseCaseProtocol
    let restoreSessionUseCase: RestoreSessionUseCaseProtocol

    lazy var loginUseCase: LoginUseCaseProtocol = {
        LoginUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol = {
        RequestEmailOtpUseCase(repository: authRepository)
    }()

    lazy var requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol = {
        RequestPhoneOtpUseCase(repository: authRepository)
    }()

    lazy var verifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol = {
        VerifyPhoneOtpUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var googleSignInUseCase: GoogleSignInUseCaseProtocol = {
        GoogleSignInUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var registerUseCase: RegisterUseCaseProtocol = {
        RegisterUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var logoutUseCase: LogoutUseCaseProtocol = {
        LogoutUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var forgotPasswordUseCase: ForgotPasswordUseCaseProtocol = {
        ForgotPasswordUseCase(repository: authRepository)
    }()

    lazy var resetPasswordUseCase: ResetPasswordUseCaseProtocol = {
        ResetPasswordUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var changePasswordUseCase: ChangePasswordUseCaseProtocol = {
        ChangePasswordUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var refreshProfileUseCase: RefreshProfileUseCaseProtocol = {
        RefreshProfileUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var updateProfileUseCase: UpdateProfileUseCaseProtocol = {
        UpdateProfileUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var listSessionsUseCase: ListSessionsUseCaseProtocol = {
        ListSessionsUseCase(repository: authRepository)
    }()

    lazy var revokeSessionUseCase: RevokeSessionUseCaseProtocol = {
        RevokeSessionUseCase(repository: authRepository)
    }()

    lazy var revokeAllSessionsUseCase: RevokeAllSessionsUseCaseProtocol = {
        RevokeAllSessionsUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var deactivateAccountUseCase: DeactivateAccountUseCaseProtocol = {
        DeactivateAccountUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var deleteAccountUseCase: DeleteAccountUseCaseProtocol = {
        DeleteAccountUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol = {
        GetConnectedAccountsUseCase(repository: authRepository)
    }()

    lazy var linkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol = {
        LinkGoogleAccountUseCase(repository: authRepository)
    }()

    lazy var unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol = {
        UnlinkGoogleAccountUseCase(repository: authRepository)
    }()

    lazy var linkPhoneAccountUseCase: LinkPhoneAccountUseCaseProtocol = {
        LinkPhoneAccountUseCase(repository: authRepository)
    }()

    lazy var linkEmailAccountUseCase: LinkEmailAccountUseCaseProtocol = {
        LinkEmailAccountUseCase(repository: authRepository)
    }()

    // MARK: - Feed

    private lazy var feedRepository: FeedRepositoryProtocol = {
        FeedRepository(apiClient: apiClient)
    }()

    lazy var fetchFeedUseCase: FetchFeedUseCaseProtocol = {
        if let simulation { return simulation.fetchFeedUseCase }
        return FetchFeedUseCase(repository: feedRepository)
    }()

    lazy var reactToPostUseCase: ReactToPostUseCaseProtocol = {
        if let simulation { return simulation.reactToPostUseCase }
        return ReactToPostUseCase(repository: feedRepository)
    }()

    lazy var deletePostUseCase: DeletePostUseCaseProtocol = {
        if let simulation { return simulation.deletePostUseCase }
        return DeletePostUseCase(repository: feedRepository)
    }()

    lazy var createPostUseCase: CreatePostUseCaseProtocol = {
        if let simulation { return simulation.createPostUseCase }
        return CreatePostUseCase(repository: feedRepository)
    }()

    private lazy var friendsManagementRepository: FriendsManagementRepositoryProtocol = {
        FriendsManagementRepository(apiClient: apiClient)
    }()

    private lazy var friendsRepository: FriendsRepositoryProtocol = {
        FriendsRepository(searchRepository: friendsManagementRepository)
    }()

    private lazy var groupsRepository: GroupsRepositoryProtocol = {
        GroupsRepository(apiClient: apiClient)
    }()

    lazy var fetchFriendsUseCase: FetchFriendsUseCaseProtocol = {
        FetchFriendsUseCase(repository: friendsRepository)
    }()

    lazy var fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol = {
        FetchMyFriendsUseCase(repository: friendsManagementRepository)
    }()

    lazy var searchUsersUseCase: SearchUsersUseCaseProtocol = {
        SearchUsersUseCase(repository: friendsManagementRepository)
    }()

    lazy var generateMyQrUseCase: GenerateMyQrUseCaseProtocol = {
        GenerateMyQrUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol = {
        FetchMyGroupsUseCase(repository: groupsRepository)
    }()

    lazy var addFriendUseCase: AddFriendUseCaseProtocol = {
        AddFriendUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol = {
        FetchIncomingFriendRequestsUseCase(repository: friendsManagementRepository)
    }()

    lazy var acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol = {
        AcceptFriendRequestUseCase(repository: friendsManagementRepository)
    }()

    lazy var rejectFriendRequestUseCase: RejectFriendRequestUseCaseProtocol = {
        RejectFriendRequestUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol = {
        FetchOutgoingFriendRequestsUseCase(repository: friendsManagementRepository)
    }()

    lazy var cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol = {
        CancelFriendRequestUseCase(repository: friendsManagementRepository)
    }()

    lazy var removeFriendUseCase: RemoveFriendUseCaseProtocol = {
        RemoveFriendUseCase(repository: friendsManagementRepository)
    }()

    lazy var setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol = {
        SetFriendNicknameUseCase(repository: friendsManagementRepository)
    }()

    lazy var blockUserUseCase: BlockUserUseCaseProtocol = {
        BlockUserUseCase(repository: friendsManagementRepository)
    }()

    lazy var unblockUserUseCase: UnblockUserUseCaseProtocol = {
        UnblockUserUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol = {
        FetchBlockedUsersUseCase(repository: friendsManagementRepository)
    }()

    lazy var joinGroupUseCase: JoinGroupUseCaseProtocol = {
        JoinGroupUseCase(repository: groupsRepository)
    }()

    lazy var createGroupUseCase: CreateGroupUseCaseProtocol = {
        CreateGroupUseCase(repository: groupsRepository)
    }()

    lazy var fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol = {
        FetchGroupMembersUseCase(repository: groupsRepository)
    }()

    lazy var fetchGroupInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol = {
        FetchGroupInviteCodeUseCase(repository: groupsRepository)
    }()

    lazy var generateGroupInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol = {
        GenerateGroupInviteCodeUseCase(repository: groupsRepository)
    }()

    lazy var inviteFriendsToGroupUseCase: InviteFriendsToGroupUseCaseProtocol = {
        InviteFriendsToGroupUseCase(repository: groupsRepository)
    }()

    lazy var fetchGroupUseCase: FetchGroupUseCaseProtocol = {
        FetchGroupUseCase(repository: groupsRepository)
    }()

    lazy var approveGroupMemberUseCase: ApproveGroupMemberUseCaseProtocol = {
        ApproveGroupMemberUseCase(repository: groupsRepository)
    }()

    lazy var rejectGroupMemberUseCase: RejectGroupMemberUseCaseProtocol = {
        RejectGroupMemberUseCase(repository: groupsRepository)
    }()

    lazy var removeGroupMemberUseCase: RemoveGroupMemberUseCaseProtocol = {
        RemoveGroupMemberUseCase(repository: groupsRepository)
    }()

    lazy var leaveGroupUseCase: LeaveGroupUseCaseProtocol = {
        LeaveGroupUseCase(repository: groupsRepository)
    }()

    lazy var deleteGroupUseCase: DeleteGroupUseCaseProtocol = {
        DeleteGroupUseCase(repository: groupsRepository)
    }()

    lazy var updateGroupUseCase: UpdateGroupUseCaseProtocol = {
        UpdateGroupUseCase(repository: groupsRepository)
    }()

    lazy var updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol = {
        UpdateGroupAvatarUseCase(repository: groupsRepository)
    }()

    lazy var transferGroupOwnershipUseCase: TransferGroupOwnershipUseCaseProtocol = {
        TransferGroupOwnershipUseCase(repository: groupsRepository)
    }()

    lazy var generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol = {
        GenerateGroupQrUseCase(repository: groupsRepository)
    }()

    lazy var revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol = {
        RevokeGroupQrUseCase(repository: groupsRepository)
    }()

    // MARK: - Media

    private lazy var mediaRepository: MediaRepositoryProtocol = {
        MediaRepository(apiClient: apiClient)
    }()

    lazy var uploadMediaUseCase: UploadMediaUseCaseProtocol = {
        UploadMediaUseCase(repository: mediaRepository)
    }()

  // Avatar uploads always hit media-service (URLs are persisted via auth/social).
    lazy var uploadUserAvatarUseCase: UploadUserAvatarUseCaseProtocol = {
        UploadUserAvatarUseCase(repository: mediaRepository)
    }()

    lazy var uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol = {
        UploadGroupAvatarUseCase(repository: mediaRepository)
    }()

    // MARK: - Expense

    private lazy var expenseRepository: ExpenseRepositoryProtocol = {
        ExpenseRepository(apiClient: apiClient)
    }()

    lazy var fetchExpensesUseCase: FetchExpensesUseCaseProtocol = {
        if let simulation { return simulation.fetchExpensesUseCase }
        return FetchExpensesUseCase(repository: expenseRepository)
    }()

    lazy var createExpenseUseCase: CreateExpenseUseCaseProtocol = {
        if let simulation { return simulation.createExpenseUseCase }
        return CreateExpenseUseCase(repository: expenseRepository)
    }()

    lazy var fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol = {
        if let simulation { return simulation.fetchDebtSummaryUseCase }
        return FetchDebtSummaryUseCase(repository: expenseRepository)
    }()

    // MARK: - Notification

    private lazy var notificationRepository: NotificationRepositoryProtocol = {
        NotificationRepository(apiClient: apiClient)
    }()

    lazy var fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol = {
        if let simulation { return simulation.fetchNotificationsUseCase }
        return FetchNotificationsUseCase(repository: notificationRepository)
    }()

    lazy var markNotificationReadUseCase: MarkNotificationReadUseCaseProtocol = {
        if let simulation { return simulation.markNotificationReadUseCase }
        return MarkNotificationReadUseCase(repository: notificationRepository)
    }()

    // MARK: - Init

    private init() {
        let tokenProvider = InMemoryTokenProvider()
        self.tokenProvider = tokenProvider
        self.keychainService = KeychainService()
        self.userDefaultsService = UserDefaultsService()
        self.sessionManager = SessionManager()

        let refreshCoordinator = TokenRefreshCoordinator()
        let apiClient = APIClient(tokenProvider: tokenProvider, tokenRefresher: refreshCoordinator)
        let authRepository = AuthRepository(
            apiClient: apiClient,
            keychainService: keychainService,
            tokenProvider: tokenProvider
        )
        let refreshTokenUseCase = RefreshTokenUseCase(
            repository: authRepository,
            sessionManager: sessionManager,
            tokenProvider: tokenProvider
        )
        refreshCoordinator.configure { [refreshTokenUseCase] in
            try await refreshTokenUseCase.refreshSession()
        }

        self.apiClient = apiClient
        self.authRepository = authRepository
        self.refreshTokenUseCase = refreshTokenUseCase
        self.restoreSessionUseCase = RestoreSessionUseCase(
            repository: authRepository,
            sessionManager: sessionManager,
            keychainService: keychainService,
            tokenProvider: tokenProvider,
            refreshTokenUseCase: refreshTokenUseCase
        )

        if AppConstants.Dev.useMockData {
            let simulation = SimulationContainer(loggerModule: "SplickApp")
            self.simulation = simulation
            Task { await simulation.seedTestData() }
        } else {
            self.simulation = nil
        }
    }
}
