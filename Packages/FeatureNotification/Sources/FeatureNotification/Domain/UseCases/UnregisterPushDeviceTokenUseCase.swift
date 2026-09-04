import Foundation

public protocol UnregisterPushDeviceTokenUseCaseProtocol: Sendable {
    func execute(token: String) async throws
}

public final class UnregisterPushDeviceTokenUseCase: UnregisterPushDeviceTokenUseCaseProtocol, Sendable {
    private let repository: NotificationRepositoryProtocol

    public init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(token: String) async throws {
        try await repository.unregisterDeviceToken(token: token)
    }
}
