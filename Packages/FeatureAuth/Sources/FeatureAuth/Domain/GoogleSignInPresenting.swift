import Foundation

/// Presents the Google account picker and returns a Google ID token for backend exchange.
@MainActor
public protocol GoogleSignInPresenting: AnyObject {
    var isAvailable: Bool { get }
    func fetchIdToken() async throws -> String
}
