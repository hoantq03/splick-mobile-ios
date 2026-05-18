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

    lazy var apiClient: APIClientProtocol = {
        APIClient(tokenProvider: tokenProvider)
    }()

    // MARK: - Session

    let sessionManager: SessionManagerProtocol

    // MARK: - Auth

    private lazy var authRepository: AuthRepositoryProtocol = {
        AuthRepository(
            apiClient: apiClient,
            keychainService: keychainService,
            tokenProvider: tokenProvider
        )
    }()

    lazy var loginUseCase: LoginUseCaseProtocol = {
        if let simulation { return simulation.loginUseCase }
        return LoginUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var registerUseCase: RegisterUseCaseProtocol = {
        if let simulation { return simulation.registerUseCase }
        return RegisterUseCase(repository: authRepository, sessionManager: sessionManager)
    }()

    lazy var logoutUseCase: LogoutUseCaseProtocol = {
        if let simulation { return simulation.logoutUseCase }
        return LogoutUseCase(repository: authRepository, sessionManager: sessionManager)
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

        if AppConstants.Dev.useMockData {
            let simulation = SimulationContainer(loggerModule: "SplickApp")
            self.simulation = simulation
            self.sessionManager = simulation.sessionManager
            Task { await simulation.seedTestData() }
        } else {
            self.simulation = nil
            self.sessionManager = SessionManager()
        }
    }
}
