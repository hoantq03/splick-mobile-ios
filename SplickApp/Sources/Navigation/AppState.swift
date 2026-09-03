import Foundation
import SwiftUI
import SplickDomain
import Common
import Storage
import Localization
import FeatureFriends
import FeatureSocialFeed

@MainActor
final class AppState: ObservableObject {
    enum AuthState: Equatable {
        case unknown
        case authenticated(User)
        case unauthenticated
    }

    @Published var authState: AuthState = .unknown
    @Published var selectedTab: Tab = .feed
    @Published var showProfileSettings = false
    @Published var showNotifications = false
    @Published var needsOAuthProfileSetup = false
    @Published var notificationAnchorFrame: CGRect = .zero
    @Published var feedNavigationPath = NavigationPath()
    @Published var pendingFeedPostNavigation: PendingFeedPostNavigation?
    /// Slides in over the current tab (e.g. expense row → post detail).
    @Published var linkedPostPresentation: PendingFeedPostNavigation?

    @Published var pendingMessagingNavigation: PendingMessagingNavigation?
    /// True while Messages has a pushed chat thread. Drives tab-bar chrome so a
    /// notification/deep-link open cannot leave the floating menu over the composer.
    @Published var isMessagingThreadPresented = false
    @Published var pendingUserProfileNavigation: UUID? {
        didSet { persistPendingUserProfileUserId() }
    }
    @Published var pendingUserProfileUsername: String? {
        didSet { persistPendingUserProfileUsername() }
    }
    @Published var pendingBillInviteToken: String?
    @Published var pendingBillInviteSplitId: UUID?

    /// In-memory only — `false` every cold launch and after logout.
    /// `true` only after the user taps through the 4-page onboarding this session.
    @Published private(set) var hasPassedOnboardingThisSession = false

    /// `false` = splash overlay is visible; `true` = splash has slid away.
    @Published private(set) var isLaunchSplashComplete = false
    @Published private(set) var splashSessionID = UUID()

    /// Returning users skip the blocking splash and hydrate from cache immediately.
    private let hadStoredCredentialsAtLaunch: Bool = {
        guard let token = try? KeychainService().loadString(for: AppConstants.Keychain.accessTokenKey) else {
            return false
        }
        return !token.isEmpty
    }()

    init() {
        if let stored = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.pendingBillInviteToken),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pendingBillInviteToken = stored
            hasPassedOnboardingThisSession = true
            if let rawSplit = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.pendingBillInviteSplitId) {
                pendingBillInviteSplitId = UUID(uuidString: rawSplit)
            }
        }
        if let rawProfile = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.pendingUserProfileUserId),
           let userId = UUID(uuidString: rawProfile) {
            pendingUserProfileNavigation = userId
        }
        if let username = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.pendingUserProfileUsername),
           !username.isEmpty {
            pendingUserProfileUsername = username
        }
    }

    var needsSplash: Bool {
        if isAuthenticated || hadStoredCredentialsAtLaunch { return false }
        return !isLaunchSplashComplete
    }

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    var currentUser: User? {
        if case .authenticated(let user) = authState { return user }
        return nil
    }

    func setAuthenticated(user: User, needsOAuthProfileSetup: Bool = false) {
        authState = .authenticated(user)
        self.needsOAuthProfileSetup = needsOAuthProfileSetup
        isLaunchSplashComplete = true
        Log.info("User authenticated: \(user.username)", category: .lifecycle)
        Log.debug("Navigate to main tabs", category: .ui)
    }

    func completeOAuthProfileSetup() {
        needsOAuthProfileSetup = false
    }

    func updateAuthenticatedUser(_ user: User) {
        guard case .authenticated = authState else { return }
        authState = .authenticated(user)
    }

    func setUnauthenticated(container: DependencyContainer) {
        container.resetTabViewModels()
        container.widgetSyncBridge.clearAll()
        authState = .unauthenticated
        hasPassedOnboardingThisSession = false
        isLaunchSplashComplete = true
        needsOAuthProfileSetup = false
        selectedTab = .feed
        showNotifications = false
        feedNavigationPath = NavigationPath()
        pendingFeedPostNavigation = nil
        linkedPostPresentation = nil
        pendingMessagingNavigation = nil
        isMessagingThreadPresented = false
        clearPendingUserProfileNavigation()
        PushNotificationCoordinator.shared.syncAppIconBadge(count: 0)
        Log.info("User signed out", category: .lifecycle)
    }

    /// Called when session restore determines there is no active session.
    /// Does NOT replay the splash — caller controls that.
    func markUnauthenticated(container: DependencyContainer) {
        container.resetTabViewModels()
        container.widgetSyncBridge.clearAll()
        authState = .unauthenticated
        selectedTab = .feed
        showNotifications = false
        feedNavigationPath = NavigationPath()
        pendingFeedPostNavigation = nil
        linkedPostPresentation = nil
        pendingMessagingNavigation = nil
        isMessagingThreadPresented = false
        PushNotificationCoordinator.shared.syncAppIconBadge(count: 0)
    }

    func clearPendingMessagingNavigation() {
        pendingMessagingNavigation = nil
    }

    /// Opens a chat thread from profile / deep link: switch to Messages and push the conversation.
    func openConversation(_ conversationId: UUID, highlightMessageId: UUID? = nil) {
        pendingMessagingNavigation = PendingMessagingNavigation(
            conversationId: conversationId,
            highlightMessageId: highlightMessageId
        )
        // Hide chrome before the pager settles — otherwise `reset()` after the
        // tab slide puts the menu on top of the composer.
        isMessagingThreadPresented = true
        withAnimation(.easeInOut(duration: 0.35)) {
            selectedTab = .messages
        }
        showNotifications = false
        showProfileSettings = false
    }

    func clearPendingUserProfileNavigation() {
        pendingUserProfileNavigation = nil
        pendingUserProfileUsername = nil
    }

    func openUserProfile(_ userId: UUID) {
        pendingUserProfileUsername = nil
        pendingUserProfileNavigation = userId
        withAnimation(.easeInOut(duration: 0.35)) {
            selectedTab = .friends
        }
        showNotifications = false
        showProfileSettings = false
    }

    func openUserProfile(username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        guard !trimmed.isEmpty, !Self.reservedWebPaths.contains(trimmed.lowercased()) else { return }
        pendingUserProfileNavigation = nil
        pendingUserProfileUsername = trimmed
        withAnimation(.easeInOut(duration: 0.35)) {
            selectedTab = .friends
        }
        showNotifications = false
        showProfileSettings = false
    }

    private func persistPendingUserProfileUserId() {
        if let userId = pendingUserProfileNavigation {
            UserDefaults.standard.set(
                userId.uuidString,
                forKey: AppConstants.UserDefaults.pendingUserProfileUserId
            )
        } else {
            UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaults.pendingUserProfileUserId)
        }
    }

    private func persistPendingUserProfileUsername() {
        if let username = pendingUserProfileUsername, !username.isEmpty {
            UserDefaults.standard.set(
                username,
                forKey: AppConstants.UserDefaults.pendingUserProfileUsername
            )
        } else {
            UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaults.pendingUserProfileUsername)
        }
    }

    private static let reservedWebPaths: Set<String> = [
        "privacy", "terms", "support", "invite", "vi", "dashboard", "admin",
        "group", "b", "u", "post", "friends", "messages", "feed",
    ]

    func handleDeepLink(_ url: URL) -> Bool {
        let parsed = SplickQRParser.parse(url.absoluteString)
        if url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http" {
            switch parsed {
            case .claimBill(let token, let splitId):
                storePendingBillInvite(token, splitId: splitId)
                return true
            case .addFriend(let username):
                openUserProfile(username: username)
                return true
            default:
                return false
            }
        }
        guard url.scheme?.lowercased() == "splick" else { return false }
        switch parsed {
        case .claimBill(let token, let splitId):
            storePendingBillInvite(token, splitId: splitId)
            return true
        case .addFriend(let username):
            openUserProfile(username: username)
            return true
        default:
            break
        }
        switch url.host?.lowercased() {
        case "user":
            if let userId = uuidPathComponent(url) {
                openUserProfile(userId)
                return true
            }
            return false
        case "capture", "postcapture":
            openPostCapture()
            return true
        case "expenses":
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedTab = .expenses
            }
            return true
        case "messages":
            if let conversationId = uuidPathComponent(url) {
                openConversation(conversationId)
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    selectedTab = .messages
                }
            }
            return true
        case "chat":
            if let conversationId = uuidPathComponent(url) {
                openConversation(conversationId)
                return true
            }
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedTab = .messages
            }
            return true
        case "friends":
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedTab = .friends
            }
            return true
        default:
            return false
        }
    }

    /// Called when user taps through the last onboarding page.
    func passOnboardingGate() {
        hasPassedOnboardingThisSession = true
    }

    func openPostCapture() {
        withAnimation(.easeInOut(duration: 0.35)) {
            selectedTab = .camera
        }
    }

    func storePendingBillInvite(_ token: String, splitId: UUID? = nil) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: AppConstants.UserDefaults.pendingBillInviteToken)
        pendingBillInviteToken = trimmed
        pendingBillInviteSplitId = splitId
        if let splitId {
            UserDefaults.standard.set(splitId.uuidString, forKey: AppConstants.UserDefaults.pendingBillInviteSplitId)
        } else {
            UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaults.pendingBillInviteSplitId)
        }
        hasPassedOnboardingThisSession = true
    }

    func consumePendingBillInvite() -> (token: String, splitId: UUID?)? {
        let stored = pendingBillInviteToken
            ?? UserDefaults.standard.string(forKey: AppConstants.UserDefaults.pendingBillInviteToken)
        let split = pendingBillInviteSplitId
            ?? UserDefaults.standard.string(forKey: AppConstants.UserDefaults.pendingBillInviteSplitId)
            .flatMap(UUID.init)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaults.pendingBillInviteToken)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaults.pendingBillInviteSplitId)
        pendingBillInviteToken = nil
        pendingBillInviteSplitId = nil
        guard let stored, !stored.isEmpty else { return nil }
        return (stored, split)
    }

    private func uuidPathComponent(_ url: URL) -> UUID? {
        url.pathComponents
            .filter { $0 != "/" }
            .compactMap(UUID.init(uuidString:))
            .first
    }

    func openPostFromNotification(_ postId: UUID, commentId: UUID? = nil) {
        pendingFeedPostNavigation = PendingFeedPostNavigation(
            postId: postId,
            expandBillSplit: false,
            commentId: commentId
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            selectedTab = .feed
        }
        Log.debug(
            "Navigate to post from notification",
            category: .ui,
            metadata: ["postId": postId.uuidString, "tab": Tab.feed.rawValue]
        )
    }

    func openLinkedPost(_ postId: UUID, expandBillSplit: Bool) {
        linkedPostPresentation = PendingFeedPostNavigation(
            postId: postId,
            expandBillSplit: expandBillSplit
        )
        Log.debug(
            "Present linked post overlay",
            category: .ui,
            metadata: [
                "postId": postId.uuidString,
                "expandBillSplit": String(expandBillSplit),
            ]
        )
    }

    func dismissLinkedPostPresentation() {
        linkedPostPresentation = nil
    }

    func presentNotifications(from bellFrame: CGRect) {
        guard bellFrame.width > 1, bellFrame.height > 1 else { return }
        Task { @MainActor in
            notificationAnchorFrame = bellFrame
            showNotifications = true
        }
    }

    func routeRemoteNotification(_ destination: NotificationDestination) {
        routeNotification(target: navigationTarget(from: destination))
    }

    func routeNotification(target: NotificationNavigationTarget) {
        switch target {
        case .post(let postId, let commentId):
            openPostFromNotification(postId, commentId: commentId)
        case .feed:
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedTab = .feed
            }
            showNotifications = false
        case .expenses:
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedTab = .expenses
            }
            showNotifications = false
        case .friends:
            selectedTab = .friends
            showNotifications = false
        case .userProfile(let userId):
            openUserProfile(userId)
        case .messages:
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedTab = .messages
            }
            showNotifications = false
        case .conversation(let conversationId, let highlightMessageId):
            openConversation(conversationId, highlightMessageId: highlightMessageId)
        case .inbox:
            selectedTab = .feed
            showNotifications = true
        case .none:
            break
        }
    }

    private func navigationTarget(from destination: NotificationDestination) -> NotificationNavigationTarget {
        switch destination.screen {
        case .postDetail:
            if let postId = destination.postDetailId {
                return .post(postId, commentId: destination.commentId)
            }
            return .feed
        case .feed:
            return .feed
        case .expenses:
            return .expenses
        case .friends:
            return .friends
        case .userProfile:
            if let userId = destination.userProfileId {
                return .userProfile(userId)
            }
            return .friends
        case .messages:
            if let conversationId = destination.conversationId {
                return .conversation(conversationId)
            }
            return .messages
        case .inbox:
            return .inbox
        case .unknown:
            return .none
        }
    }

    func clearPendingPostNavigation() {
        pendingFeedPostNavigation = nil
    }

    func completeLaunchSplash() {
        withAnimation(SplashMotion.reveal) {
            isLaunchSplashComplete = true
        }
    }

    func resetGuestSplashSession() {
        isLaunchSplashComplete = false
        splashSessionID = UUID()
    }
}

struct PendingMessagingNavigation: Equatable {
    let conversationId: UUID
    let highlightMessageId: UUID?
}

enum Tab: String, CaseIterable {
    case feed
    case expenses
    case friends
    case camera
    case messages
    case profile

    @MainActor
    func localizedTitle(using languageService: LanguageService) -> String {
        switch self {
        case .feed: return languageService.text(.tabFeed)
        case .expenses: return languageService.text(.tabExpenses)
        case .friends: return languageService.text(.tabFriends)
        case .camera: return languageService.text(.tabCamera)
        case .messages: return languageService.text(.tabMessages)
        case .profile: return languageService.text(.profileTitle)
        }
    }

    var icon: String {
        switch self {
        case .feed: return "photo.on.rectangle"
        case .expenses: return "dollarsign.circle"
        case .friends: return "person.2"
        case .camera: return "camera"
        case .messages: return "message"
        case .profile: return "person.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .feed: return "photo.on.rectangle.fill"
        case .expenses: return "dollarsign.circle.fill"
        case .friends: return "person.2.fill"
        case .camera: return "camera.fill"
        case .messages: return "message.fill"
        case .profile: return "person.circle.fill"
        }
    }
}
