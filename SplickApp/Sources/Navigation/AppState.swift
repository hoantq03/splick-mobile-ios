import Foundation
import SwiftUI
import SplickDomain
import Common
import Localization
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
    @Published var notificationAnchorFrame: CGRect = .zero
    @Published var feedNavigationPath = NavigationPath()
    @Published var pendingFeedPostNavigation: PendingFeedPostNavigation?
    /// Slides in over the current tab (e.g. expense row → post detail).
    @Published var linkedPostPresentation: PendingFeedPostNavigation?

    /// In-memory only — `false` every cold launch and after logout.
    /// `true` only after the user taps through the 4-page onboarding this session.
    @Published private(set) var hasPassedOnboardingThisSession = false

    /// `false` = splash overlay is visible; `true` = splash has slid away.
    @Published private(set) var isLaunchSplashComplete = false
    @Published private(set) var splashSessionID = UUID()

    var needsSplash: Bool {
        !isAuthenticated && !isLaunchSplashComplete
    }

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    var currentUser: User? {
        if case .authenticated(let user) = authState { return user }
        return nil
    }

    func setAuthenticated(user: User) {
        authState = .authenticated(user)
        isLaunchSplashComplete = true
        Log.info("User authenticated: \(user.username)", category: .lifecycle)
        Log.debug("Navigate to main tabs", category: .ui)
    }

    func updateAuthenticatedUser(_ user: User) {
        guard case .authenticated = authState else { return }
        authState = .authenticated(user)
    }

    func setUnauthenticated(container: DependencyContainer) {
        container.resetTabViewModels()
        authState = .unauthenticated
        hasPassedOnboardingThisSession = false
        isLaunchSplashComplete = true
        selectedTab = .feed
        showNotifications = false
        feedNavigationPath = NavigationPath()
        pendingFeedPostNavigation = nil
        linkedPostPresentation = nil
        Log.info("User signed out", category: .lifecycle)
    }

    /// Called when session restore determines there is no active session.
    /// Does NOT replay the splash — caller controls that.
    func markUnauthenticated(container: DependencyContainer) {
        container.resetTabViewModels()
        authState = .unauthenticated
        selectedTab = .feed
        showNotifications = false
        feedNavigationPath = NavigationPath()
        pendingFeedPostNavigation = nil
        linkedPostPresentation = nil
    }

    /// Called when user taps through the last onboarding page.
    func passOnboardingGate() {
        hasPassedOnboardingThisSession = true
    }

    func openPostFromNotification(_ postId: UUID) {
        pendingFeedPostNavigation = PendingFeedPostNavigation(
            postId: postId,
            expandBillSplit: false
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
        case .post(let postId):
            openPostFromNotification(postId)
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
        case .messages:
            selectedTab = .messages
            showNotifications = false
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
                return .post(postId)
            }
            return .feed
        case .feed:
            return .feed
        case .expenses:
            return .expenses
        case .friends:
            return .friends
        case .messages:
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
