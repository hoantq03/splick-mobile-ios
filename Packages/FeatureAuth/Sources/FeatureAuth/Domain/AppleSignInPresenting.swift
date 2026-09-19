import Foundation

/// Presents Sign in with Apple and returns an Apple identity token for backend exchange.
@MainActor
public protocol AppleSignInPresenting: AnyObject {
    var isAvailable: Bool { get }
    func fetchIdToken() async throws -> String
}

public enum AppleSignInError: LocalizedError, Equatable {
    case cancelled
    case missingIdToken

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in with Apple was cancelled."
        case .missingIdToken:
            return "Apple did not return an identity token."
        }
    }
}
