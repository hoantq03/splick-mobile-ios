import Foundation
import Common

/// Deferred wiring for token refresh to break APIClient ↔ AuthRepository cycles.
public final class TokenRefreshCoordinator: TokenRefreshHandling, @unchecked Sendable {
    private var refreshHandler: (@Sendable () async throws -> Void)?

    public init() {}

    public func configure(refreshHandler: @escaping @Sendable () async throws -> Void) {
        self.refreshHandler = refreshHandler
    }

    public func refreshSession() async throws {
        guard let refreshHandler else {
            throw AuthError.refreshFailed
        }
        try await refreshHandler()
    }
}
