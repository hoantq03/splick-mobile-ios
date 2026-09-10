import Foundation
import SplickDomain

public protocol UpdateProfileUseCaseProtocol: Sendable {
    func execute(
        displayName: String?,
        avatarUrl: String?,
        preferredLocale: String?,
        dateOfBirth: Date?,
        username: String?,
        timezone: String?
    ) async throws -> User
}

public final class UpdateProfileUseCase: UpdateProfileUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(
        displayName: String?,
        avatarUrl: String?,
        preferredLocale: String? = nil,
        dateOfBirth: Date? = nil,
        username: String? = nil,
        timezone: String? = nil
    ) async throws -> User {
        let user = try await repository.updateProfile(
            displayName: displayName,
            avatarUrl: avatarUrl,
            preferredLocale: preferredLocale,
            dateOfBirth: dateOfBirth,
            username: username,
            timezone: timezone
        )
        if let session = await sessionManager.currentSession() {
            await sessionManager.setSession(AuthSession(user: user, token: session.token))
        }
        return user
    }
}

public extension UpdateProfileUseCaseProtocol {
    func execute(
        displayName: String?,
        avatarUrl: String?,
        preferredLocale: String?
    ) async throws -> User {
        try await execute(
            displayName: displayName,
            avatarUrl: avatarUrl,
            preferredLocale: preferredLocale,
            dateOfBirth: nil,
            username: nil,
            timezone: nil
        )
    }

    func execute(
        displayName: String?,
        avatarUrl: String?,
        preferredLocale: String?,
        dateOfBirth: Date?
    ) async throws -> User {
        try await execute(
            displayName: displayName,
            avatarUrl: avatarUrl,
            preferredLocale: preferredLocale,
            dateOfBirth: dateOfBirth,
            username: nil,
            timezone: nil
        )
    }
}
