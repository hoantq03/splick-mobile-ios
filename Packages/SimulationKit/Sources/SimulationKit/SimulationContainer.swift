import Foundation
import Networking
import Storage
import Common
import SplickDomain
import FeatureAuth
import FeatureSocialFeed
import FeatureExpense
import FeatureNotification
import FeatureMedia

public final class SimulationContainer: @unchecked Sendable {
    public let logger: StateLogger
    public let mockAPI: MockAPIClient
    public let mockTokenProvider: MockTokenProvider
    public let mockKeychain: MockKeychainService

    // Repositories
    public let authRepository: FakeAuthRepository
    public let feedRepository: FakeFeedRepository
    public let expenseRepository: FakeExpenseRepository
    public let notificationRepository: FakeNotificationRepository

    // Session
    public let sessionManager: SessionManager

    // Use Cases — Auth
    public let loginUseCase: LoginUseCase
    public let registerUseCase: RegisterUseCase
    public let logoutUseCase: LogoutUseCase

    // Use Cases — Feed
    public let fetchFeedUseCase: FetchFeedUseCase
    public let reactToPostUseCase: ReactToPostUseCase

    // Use Cases — Expense
    public let fetchExpensesUseCase: FetchExpensesUseCase
    public let createExpenseUseCase: CreateExpenseUseCase
    public let fetchDebtSummaryUseCase: FetchDebtSummaryUseCase

    // Use Cases — Notification
    public let fetchNotificationsUseCase: FetchNotificationsUseCase
    public let markNotificationReadUseCase: MarkNotificationReadUseCase

    public init(loggerModule: String = "Simulation") {
        self.logger = StateLogger(module: loggerModule)
        self.mockAPI = MockAPIClient()
        self.mockTokenProvider = MockTokenProvider()
        self.mockKeychain = MockKeychainService(logger: logger)

        // Repositories
        self.authRepository = FakeAuthRepository(logger: StateLogger(module: "Auth"))
        self.feedRepository = FakeFeedRepository(logger: StateLogger(module: "Feed"))
        self.expenseRepository = FakeExpenseRepository(logger: StateLogger(module: "Expense"))
        self.notificationRepository = FakeNotificationRepository(logger: StateLogger(module: "Notification"))

        // Session
        self.sessionManager = SessionManager()

        // Auth Use Cases
        self.loginUseCase = LoginUseCase(repository: authRepository, sessionManager: sessionManager)
        self.registerUseCase = RegisterUseCase(repository: authRepository, sessionManager: sessionManager)
        self.logoutUseCase = LogoutUseCase(repository: authRepository, sessionManager: sessionManager)

        // Feed Use Cases
        self.fetchFeedUseCase = FetchFeedUseCase(repository: feedRepository)
        self.reactToPostUseCase = ReactToPostUseCase(repository: feedRepository)

        // Expense Use Cases
        self.fetchExpensesUseCase = FetchExpensesUseCase(repository: expenseRepository)
        self.createExpenseUseCase = CreateExpenseUseCase(repository: expenseRepository)
        self.fetchDebtSummaryUseCase = FetchDebtSummaryUseCase(repository: expenseRepository)

        // Notification Use Cases
        self.fetchNotificationsUseCase = FetchNotificationsUseCase(repository: notificationRepository)
        self.markNotificationReadUseCase = MarkNotificationReadUseCase(repository: notificationRepository)
    }

    public func seedTestData() async {
        await authRepository.seed()
        await feedRepository.seed()
        await expenseRepository.seed()
        await notificationRepository.seed()
        logger.log("Test data seeded for all modules")
    }
}
