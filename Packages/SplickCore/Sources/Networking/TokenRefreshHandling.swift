import Foundation

/// Coordinates access-token refresh when an authenticated request receives HTTP 401.
public protocol TokenRefreshHandling: Sendable {
    func refreshSession() async throws
}
