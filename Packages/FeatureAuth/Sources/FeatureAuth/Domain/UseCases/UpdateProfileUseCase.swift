import Foundation
import SplickDomain

public protocol UpdateProfileUseCaseProtocol: Sendable {
    func execute(displayName: String?, avatarUrl: String?, preferredLocale: String?) async throws -> User
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
        preferredLocale: String? = nil
    ) async throws -> User {
        let user = try await repository.updateProfile(
            displayName: displayName,
            avatarUrl: avatarUrl,
            preferredLocale: preferredLocale
        )
        if let session = await sessionManager.currentSession() {
            await sessionManager.setSession(AuthSession(user: user, token: session.token))
        }
        return user
    }
}
