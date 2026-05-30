import Foundation
import UIKit
import GoogleSignIn
import FeatureAuth

enum GoogleSignInConfiguration {
    static var clientID: String? {
        Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
    }

    static var isConfigured: Bool {
        guard let clientID else { return false }
        return !clientID.isEmpty && !clientID.contains("REPLACE_WITH_IOS_CLIENT_ID")
    }

    static func configureIfNeeded() {
        guard isConfigured, let clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
}

@MainActor
final class GoogleSignInClient: GoogleSignInPresenting {
    static let shared = GoogleSignInClient()

    var isAvailable: Bool { GoogleSignInConfiguration.isConfigured }

    private init() {}

    func fetchIdToken() async throws -> String {
        GoogleSignInConfiguration.configureIfNeeded()
        guard isAvailable else {
            throw GoogleSignInClientError.notConfigured
        }
        guard let presenter = Self.topViewController() else {
            throw GoogleSignInClientError.noPresenter
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInClientError.missingIdToken
        }
        return idToken
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
}

enum GoogleSignInClientError: LocalizedError {
    case notConfigured
    case noPresenter
    case missingIdToken

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Set GIDClientID in Info.plist to your iOS OAuth client ID from Google Cloud Console."
        case .noPresenter:
            return "Unable to present Google Sign-In."
        case .missingIdToken:
            return "Google did not return an ID token."
        }
    }
}
