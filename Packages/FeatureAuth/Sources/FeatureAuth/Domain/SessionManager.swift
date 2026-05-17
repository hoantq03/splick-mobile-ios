import Foundation
import SplickDomain

public protocol SessionManagerProtocol: Sendable {
    func currentSession() async -> AuthSession?
    func setSession(_ session: AuthSession) async
    func clearSession() async
    func isAuthenticated() async -> Bool
}

public actor SessionManager: SessionManagerProtocol {
    private var session: AuthSession?

    public init() {}

    public func currentSession() -> AuthSession? {
        session
    }

    public func setSession(_ session: AuthSession) {
        self.session = session
    }

    public func clearSession() {
        session = nil
    }

    public func isAuthenticated() -> Bool {
        session != nil
    }
}
