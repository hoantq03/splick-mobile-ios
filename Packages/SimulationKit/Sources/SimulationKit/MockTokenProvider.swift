import Foundation
import Networking

public actor MockTokenProvider: TokenProvider {
    private var access: String?
    private var refresh: String?

    public init(accessToken: String? = nil, refreshToken: String? = nil) {
        self.access = accessToken
        self.refresh = refreshToken
    }

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
