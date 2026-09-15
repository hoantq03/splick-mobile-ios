//
//  ClipInviteViewModel.swift
//  SplickClip
//

import SwiftUI
import Combine
import Networking // Provides APIClient, APIEndpoint, HTTPMethod, InMemoryTokenProvider
import Storage   // Provides KeychainService

// MARK: - Lightweight local DTOs
// App Clips must stay small — we intentionally avoid importing FeatureFriends/SplickDomain.
// These structs mirror only the API fields the clip actually needs.

struct ClipUserDTO: Decodable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, username, displayName = "display_name", avatarURL = "avatar_url"
    }
}

struct ClipPublicProfileDTO: Decodable, Sendable {
    let userId: String
    let username: String
    let displayName: String
    let avatarUrl: URL?
    let friendCount: Int
    let postCount: Int
    /// nil = anonymous / not authenticated. Values: "NONE" | "PENDING" | "FRIENDS"
    let friendStatus: String?

    enum CodingKeys: String, CodingKey {
        case userId = "userId"
        case username, displayName, avatarUrl
        case friendCount, postCount
        case friendStatus
    }
}

// MARK: - ViewModel State

enum ClipInviteState {
    case idle
    case loading
    case loaded(ClipPublicProfileDTO)
    case inviteSent
    case error(String)
}

// MARK: - Endpoints

private struct PublicUserProfileEndpoint: APIEndpoint {
    let username: String
    var path: String { "/v1/public/users/\(username)" }
    var method: HTTPMethod { .get }
    var requiresAuth: Bool { false }
    var sendsRefreshTokenHeader: Bool { false }
}

private struct SendFriendRequestEndpoint: APIEndpoint {
    let targetUsername: String
    var path: String { "/v1/social/friendships/requests" }
    var method: HTTPMethod { .post }
    var requiresAuth: Bool { true }
    var sendsRefreshTokenHeader: Bool { true }
    var body: Encodable? { Body(username: targetUsername) }
    struct Body: Encodable { let username: String }
}

// MARK: - ViewModel

@MainActor
final class ClipInviteViewModel: ObservableObject {
    @Published var state: ClipInviteState = .idle
    @Published var isInviting: Bool = false

    private let apiClient = APIClient(tokenProvider: InMemoryTokenProvider())

    // Called from the scene via onContinueUserActivity / onOpenURL
    func handleInviteURL(_ url: URL) {
        guard let username = extractUsername(from: url) else {
            state = .error("Liên kết mời không hợp lệ.")
            return
        }
        Task { await loadProfile(username: username) }
    }

    /// Sends a friend request to the currently loaded profile.
    /// If the user is not signed in, opens the full Splick app instead.
    func sendInvite() {
        guard case .loaded(let profile) = state else { return }

        guard let token = retrieveAuthToken() else {
            openFullApp(username: profile.username)
            return
        }
        Task { await performSendInvite(username: profile.username, token: token) }
    }

    /// Opens the full Splick app deeplink so the user can sign in and then add a friend.
    func openFullApp(username: String) {
        // splick://profile/{username} — handled by SplickApp's universal link / deeplink router
        if let url = URL(string: "splick://profile/\(username)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Private

    private func loadProfile(username: String) async {
        state = .loading
        do {
            let profile: ClipPublicProfileDTO = try await apiClient.request(
                PublicUserProfileEndpoint(username: username)
            )
            state = .loaded(profile)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func performSendInvite(username: String, token: String) async {
        isInviting = true
        defer { isInviting = false }
        do {
            struct Empty: Decodable {}
            let _: Empty? = try? await apiClient.request(
                SendFriendRequestEndpoint(targetUsername: username)
            )
            state = .inviteSent
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func extractUsername(from url: URL) -> String? {
        // Supports:
        //   https://splick.app/{username}
        //   https://splick.app/invite?username={username}
        if let host = url.host, host.hasSuffix("splick.app") {
            let parts = url.pathComponents.filter { $0 != "/" }
            if let first = parts.first, !first.isEmpty { return first }
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "username" })?
            .value
    }

    /// Reads access token from Keychain (never UserDefaults — security rule).
    private func retrieveAuthToken() -> String? {
        try? KeychainService().loadString(for: "splick.accessToken")
    }
}
