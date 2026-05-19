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

    lazy var registerUseCase: RegisterUseCaseProtocol = {
        RegisterUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var logoutUseCase: LogoutUseCaseProtocol = {
        LogoutUseCase(repository: authRepository, sessionManager: sessionManager)
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

    private lazy var friendsRepository: FriendsRepositoryProtocol = {
        FriendsRepository()
    }()

    lazy var fetchFriendsUseCase: FetchFriendsUseCaseProtocol = {
        if let simulation { return simulation.fetchFriendsUseCase }
        return FetchFriendsUseCase(repository: friendsRepository)
    }()

    private lazy var friendsManagementRepository: FriendsManagementRepositoryProtocol = {
        if let simulation { return simulation.friendsRepository }
        return FriendsManagementRepository()
    }()

    private lazy var groupsRepository: GroupsRepositoryProtocol = {
        if let simulation { return simulation.friendsRepository }
        return GroupsRepository()
    }()

    lazy var fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol = {
        if let simulation { return simulation.fetchMyFriendsUseCase }
        return FetchMyFriendsUseCase(repository: friendsManagementRepository)
    }()

    lazy var fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol = {
        if let simulation { return simulation.fetchMyGroupsUseCase }
        return FetchMyGroupsUseCase(repository: groupsRepository)
    }()

    lazy var addFriendUseCase: AddFriendUseCaseProtocol = {
        if let simulation { return simulation.addFriendUseCase }
        return AddFriendUseCase(repository: friendsManagementRepository)
    }()

    lazy var joinGroupUseCase: JoinGroupUseCaseProtocol = {
        if let simulation { return simulation.joinGroupUseCase }
        return JoinGroupUseCase(repository: groupsRepository)
    }()

    // MARK: - Media

    private lazy var mediaRepository: MediaRepositoryProtocol = {
        MediaRepository(apiClient: apiClient)
    }()

    lazy var uploadMediaUseCase: UploadMediaUseCaseProtocol = {
        if let simulation { return simulation.uploadMediaUseCase }
        return UploadMediaUseCase(repository: mediaRepository)
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
