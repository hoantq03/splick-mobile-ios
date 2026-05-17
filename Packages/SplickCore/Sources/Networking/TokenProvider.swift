import Foundation

public protocol TokenProvider: Sendable {
    func accessToken() async -> String?
    func refreshToken() async -> String?
    func updateTokens(access: String, refresh: String) async
    func clearTokens() async
}

public actor InMemoryTokenProvider: TokenProvider {
    private var access: String?
    private var refresh: String?

    public init() {}

    public func accessToken() -> String? { access }
    public func refreshToken() -> String? { refresh }

    public func updateTokens(access: String, refresh: String) {
        self.access = access
        self.refresh = refresh
    }

    public func clearTokens() {
        access = nil
        refresh = nil
    }
}
