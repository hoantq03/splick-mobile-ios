import Foundation
import Networking
import Storage
import Common
import SplickDomain
import FeatureSocialFeed
import FeatureExpense
import FeatureNotification
import FeatureMedia
import FeatureFriends

/// In-memory fakes for non-auth features. Authentication always uses the live backend via `DependencyContainer`.
public final class SimulationContainer: @unchecked Sendable {
    public let logger: StateLogger
    public let mockAPI: MockAPIClient
    public let mockTokenProvider: MockTokenProvider
    public let mockKeychain: MockKeychainService

    public let feedRepository: FakeFeedRepository
    public let friendsRepository: FakeFriendsRepository
    public let expenseRepository: FakeExpenseRepository
    public let notificationRepository: FakeNotificationRepository
    public let mediaRepository: FakeMediaRepository

    public let fetchFeedUseCase: FetchFeedUseCase
    public let reactToPostUseCase: ReactToPostUseCase
    public let deletePostUseCase: DeletePostUseCase
    public let createPostUseCase: CreatePostUseCase
    public let fetchFriendsUseCase: FetchFriendsUseCase

    public let fetchMyFriendsUseCase: FetchMyFriendsUseCase
    public let fetchMyGroupsUseCase: FetchMyGroupsUseCase
    public let addFriendUseCase: AddFriendUseCase
    public let joinGroupUseCase: JoinGroupUseCase

    public let fetchExpensesUseCase: FetchExpensesUseCase
    public let createExpenseUseCase: CreateExpenseUseCase
    public let fetchDebtSummaryUseCase: FetchDebtSummaryUseCase

    public let fetchNotificationsUseCase: FetchNotificationsUseCase
    public let markNotificationReadUseCase: MarkNotificationReadUseCase

    public let uploadMediaUseCase: UploadMediaUseCase

    public init(loggerModule: String = "Simulation") {
        self.logger = StateLogger(module: loggerModule)
        self.mockAPI = MockAPIClient()
        self.mockTokenProvider = MockTokenProvider()
        self.mockKeychain = MockKeychainService(logger: logger)

        self.feedRepository = FakeFeedRepository(logger: StateLogger(module: "Feed"))
        self.friendsRepository = FakeFriendsRepository(logger: StateLogger(module: "Friends"))
        self.expenseRepository = FakeExpenseRepository(logger: StateLogger(module: "Expense"))
        self.notificationRepository = FakeNotificationRepository(logger: StateLogger(module: "Notification"))
        self.mediaRepository = FakeMediaRepository()

        self.fetchFeedUseCase = FetchFeedUseCase(repository: feedRepository)
        self.reactToPostUseCase = ReactToPostUseCase(repository: feedRepository)
        self.deletePostUseCase = DeletePostUseCase(repository: feedRepository)
        self.createPostUseCase = CreatePostUseCase(repository: feedRepository)
        self.fetchFriendsUseCase = FetchFriendsUseCase(repository: friendsRepository)
        self.fetchMyFriendsUseCase = FetchMyFriendsUseCase(repository: friendsRepository)
        self.fetchMyGroupsUseCase = FetchMyGroupsUseCase(repository: friendsRepository)
        self.addFriendUseCase = AddFriendUseCase(repository: friendsRepository)
        self.joinGroupUseCase = JoinGroupUseCase(repository: friendsRepository)

        self.fetchExpensesUseCase = FetchExpensesUseCase(repository: expenseRepository)
        self.createExpenseUseCase = CreateExpenseUseCase(repository: expenseRepository)
        self.fetchDebtSummaryUseCase = FetchDebtSummaryUseCase(repository: expenseRepository)

        self.fetchNotificationsUseCase = FetchNotificationsUseCase(repository: notificationRepository)
        self.markNotificationReadUseCase = MarkNotificationReadUseCase(repository: notificationRepository)

        self.uploadMediaUseCase = UploadMediaUseCase(repository: mediaRepository)
    }

    public func seedTestData() async {
        await feedRepository.seed()
        await friendsRepository.seed()
        await expenseRepository.seed()
        await notificationRepository.seed()
        logger.log("Test data seeded for feed, friends, expense, and notifications")
    }
}
