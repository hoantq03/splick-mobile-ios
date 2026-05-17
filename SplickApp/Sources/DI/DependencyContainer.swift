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

@MainActor
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()

    // MARK: - Core

    let tokenProvider: TokenProvider
    let keychainService: KeychainServiceProtocol
    let userDefaultsService: UserDefaultsServiceProtocol
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
        LoginUseCase(repository: authRepository, sessionManager: sessionManager)
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
        FetchFeedUseCase(repository: feedRepository)
    }()

    lazy var reactToPostUseCase: ReactToPostUseCaseProtocol = {
        ReactToPostUseCase(repository: feedRepository)
    }()

    // MARK: - Media

    private lazy var mediaRepository: MediaRepositoryProtocol = {
        MediaRepository(apiClient: apiClient)
    }()

    lazy var uploadMediaUseCase: UploadMediaUseCaseProtocol = {
        UploadMediaUseCase(repository: mediaRepository)
    }()

    // MARK: - Expense

    private lazy var expenseRepository: ExpenseRepositoryProtocol = {
        ExpenseRepository(apiClient: apiClient)
    }()

    lazy var fetchExpensesUseCase: FetchExpensesUseCaseProtocol = {
        FetchExpensesUseCase(repository: expenseRepository)
    }()

    lazy var createExpenseUseCase: CreateExpenseUseCaseProtocol = {
        CreateExpenseUseCase(repository: expenseRepository)
    }()

    lazy var fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol = {
        FetchDebtSummaryUseCase(repository: expenseRepository)
    }()

    // MARK: - Notification

    private lazy var notificationRepository: NotificationRepositoryProtocol = {
        NotificationRepository(apiClient: apiClient)
    }()

    lazy var fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol = {
        FetchNotificationsUseCase(repository: notificationRepository)
    }()

    lazy var markNotificationReadUseCase: MarkNotificationReadUseCaseProtocol = {
        MarkNotificationReadUseCase(repository: notificationRepository)
    }()

    // MARK: - Init

    private init() {
        let tokenProvider = InMemoryTokenProvider()
        self.tokenProvider = tokenProvider
        self.keychainService = KeychainService()
        self.userDefaultsService = UserDefaultsService()
        self.sessionManager = SessionManager()
    }
}
