import Foundation
import Common
import Storage
import SplickDomain

public protocol SessionManagerProtocol: Sendable {
    func currentSession() async -> AuthSession?
    func setSession(_ session: AuthSession) async
    func clearSession() async
    func isAuthenticated() async -> Bool
}

public actor SessionManager: SessionManagerProtocol {
    private var session: AuthSession?
    private let userDefaultsService: UserDefaultsServiceProtocol

    public init(userDefaultsService: UserDefaultsServiceProtocol = UserDefaultsService()) {
        self.userDefaultsService = userDefaultsService
    }

    public func currentSession() -> AuthSession? {
        session
    }

    public func setSession(_ session: AuthSession) {
        self.session = session
        if hasPersistedProfile(session.user) {
            userDefaultsService.set(session.user, for: AppConstants.UserDefaults.cachedCurrentUser)
        }
    }

    public func clearSession() {
        session = nil
        userDefaultsService.remove(for: AppConstants.UserDefaults.cachedCurrentUser)
    }

    public func isAuthenticated() -> Bool {
        session != nil
    }

    private func hasPersistedProfile(_ user: User) -> Bool {
        !user.email.isEmpty || !user.username.isEmpty || !user.displayName.isEmpty
    }
}

