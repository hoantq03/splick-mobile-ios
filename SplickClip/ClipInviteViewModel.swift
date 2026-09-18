//
//  ClipInviteViewModel.swift
//  SplickClip
//

import Combine
import Common
import Foundation
import Localization
import Networking
import Storage
import SwiftUI

// MARK: - Lightweight local DTOs
// App Clips must stay small — we intentionally avoid importing FeatureFriends/SplickDomain.

struct ClipPublicProfileDTO: Decodable, Sendable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let friendCount: Int
    let postCount: Int
    /// nil = anonymous / not authenticated. Values: "NONE" | "PENDING" | "FRIENDS"
    let friendStatus: String?

    var avatarURL: URL? {
        guard let avatarUrl, !avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(string: avatarUrl)
    }

    var resolvedFriendStatus: ClipFriendStatus {
        ClipFriendStatus(rawValue: friendStatus ?? "") ?? .none
    }

    var visibleStats: [ClipProfileStat] {
        var stats: [ClipProfileStat] = []
        if friendCount > 0 {
            stats.append(ClipProfileStat(value: friendCount, labelKey: .clipStatsFriends))
        }
        if postCount > 0 {
            stats.append(ClipProfileStat(value: postCount, labelKey: .clipStatsPosts))
        }
        return stats
    }
}

struct ClipProfileStat: Hashable, Sendable {
    let value: Int
    let labelKey: L10nKey
}

enum ClipFriendStatus: String, Sendable {
    case none = "NONE"
    case pending = "PENDING"
    case friends = "FRIENDS"
}

enum ClipInviteState {
    case idle
    case loading
    case loaded(ClipPublicProfileDTO)
    case inviteSent
    case error(title: String, message: String)
}

private struct PublicUserProfileEndpoint: APIEndpoint {
    let username: String
    var path: String {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        return "/v1/public/users/\(encoded)"
    }
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
    var body: Encodable? { Body(username: targetUsername, message: nil) }
    struct Body: Encodable {
        let username: String
        let message: String?
    }
}

@MainActor
final class ClipInviteViewModel: ObservableObject {
    @Published var state: ClipInviteState = .idle
    @Published var isInviting = false

    private let apiClient: APIClient
    private let tokenProvider: InMemoryTokenProvider
    private let languageService: LanguageService
    private let keychain: KeychainServiceProtocol
    private var lastAttemptedUsername: String?

    private static let reservedPathSegments: Set<String> = [
        "invite", "privacy", "terms", "support", "admin", "app", "download",
        "legal", "bills", "bill", "api", "www", "help", "blog",
    ]

    init(
        languageService: LanguageService,
        keychain: KeychainServiceProtocol = KeychainService()
    ) {
        self.languageService = languageService
        self.keychain = keychain
        let tokenProvider = InMemoryTokenProvider()
        self.tokenProvider = tokenProvider
        self.apiClient = APIClient(
            tokenProvider: tokenProvider,
            localeProvider: languageService
        )
    }

    func prepareSession() async {
        guard let access = try? keychain.loadString(for: AppConstants.Keychain.accessTokenKey),
              !access.isEmpty else { return }
        let refresh = (try? keychain.loadString(for: AppConstants.Keychain.refreshTokenKey)) ?? ""
        await tokenProvider.updateTokens(access: access, refresh: refresh)
    }

    func handleInviteURL(_ url: URL) {
        guard let username = extractUsername(from: url) else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                state = .error(
                    title: languageService.text(.clipNotFoundTitle),
                    message: languageService.text(.clipNotFoundMessage)
                )
            }
            return
        }
        lastAttemptedUsername = username
        Task { await loadProfile(username: username) }
    }

    func retry() {
        guard let username = lastAttemptedUsername else { return }
        Task { await loadProfile(username: username) }
    }

    func sendInvite() {
        guard case .loaded(let profile) = state else { return }
        Task {
            await prepareSession()
            guard await tokenProvider.accessToken() != nil else {
                openFullApp(username: profile.username)
                return
            }
            await performSendInvite(username: profile.username)
        }
    }

    func openFullApp(username: String) {
        if let url = URL(string: "splick://friend/\(username)") {
            UIApplication.shared.open(url)
        }
    }

    private func loadProfile(username: String) async {
        state = .loading
        do {
            let profile: ClipPublicProfileDTO = try await apiClient.request(
                PublicUserProfileEndpoint(username: username)
            )
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                state = .loaded(profile)
            }
        } catch {
            let isNotFound = (error as? NetworkError) == .notFound
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                state = .error(
                    title: languageService.text(isNotFound ? .clipNotFoundTitle : .clipLoadErrorTitle),
                    message: isNotFound
                        ? languageService.text(.clipNotFoundMessage)
                        : languageService.localizedMessage(for: error)
                )
            }
        }
    }

    private func performSendInvite(username: String) async {
        isInviting = true
        defer { isInviting = false }

        do {
            try await apiClient.request(SendFriendRequestEndpoint(targetUsername: username))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                state = .inviteSent
            }
        } catch {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                state = .error(
                    title: languageService.text(.clipLoadErrorTitle),
                    message: languageService.localizedMessage(for: error)
                )
            }
        }
    }

    func extractUsername(from url: URL) -> String? {
        if let queryName = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "username" })?
            .value {
            return sanitizedUsername(queryName)
        }

        guard let host = url.host?.lowercased(), host.hasSuffix("splick.app") else {
            return nil
        }

        let parts = url.pathComponents.filter { $0 != "/" }
        guard let first = parts.first else { return nil }
        if first.lowercased() == "invite", parts.count >= 2 {
            return sanitizedUsername(parts[1])
        }
        if Self.reservedPathSegments.contains(first.lowercased()) {
            return nil
        }
        return sanitizedUsername(first)
    }

    private func sanitizedUsername(_ raw: String) -> String? {
        let username = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValid = username.range(of: "^[a-zA-Z0-9_.]{3,50}$", options: .regularExpression) != nil
        return isValid ? username : nil
    }
}
