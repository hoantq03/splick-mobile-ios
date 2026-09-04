import Foundation

public protocol RegisterPushDeviceTokenUseCaseProtocol: Sendable {
    func execute(
        token: String,
        bundleId: String,
        environment: String
    ) async throws
}

public final class RegisterPushDeviceTokenUseCase: RegisterPushDeviceTokenUseCaseProtocol, Sendable {
    private let repository: NotificationRepositoryProtocol

    public init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        token: String,
        bundleId: String,
        environment: String
    ) async throws {
        try await repository.registerDeviceToken(
            token: token,
            bundleId: bundleId,
            environment: environment
        )
    }
}
