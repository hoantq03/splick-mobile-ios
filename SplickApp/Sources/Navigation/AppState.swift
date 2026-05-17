import Foundation
import SwiftUI
import SplickDomain
import Common

@MainActor
final class AppState: ObservableObject {
    enum AuthState: Equatable {
        case unknown
        case authenticated(User)
        case unauthenticated
    }

    @Published var authState: AuthState = .unknown
    @Published var selectedTab: Tab = .feed

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
        Log.info("User authenticated: \(user.username)", category: .lifecycle)
    }

    func setUnauthenticated() {
        authState = .unauthenticated
        selectedTab = .feed
        Log.info("User signed out", category: .lifecycle)
    }
}

enum Tab: String, CaseIterable {
    case feed = "Feed"
    case expenses = "Expenses"
    case camera = "Camera"
    case notifications = "Notifications"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .feed: return "photo.on.rectangle"
        case .expenses: return "dollarsign.circle"
        case .camera: return "camera"
        case .notifications: return "bell"
        case .profile: return "person.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .feed: return "photo.on.rectangle.fill"
        case .expenses: return "dollarsign.circle.fill"
        case .camera: return "camera.fill"
        case .notifications: return "bell.fill"
        case .profile: return "person.circle.fill"
        }
    }
}
