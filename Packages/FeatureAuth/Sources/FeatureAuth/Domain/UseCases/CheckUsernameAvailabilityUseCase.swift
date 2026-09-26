import Foundation
import Common
import Localization

public protocol CheckUsernameAvailabilityUseCaseProtocol: Sendable {
    func execute(username: String) async throws -> Bool
}

public final class CheckUsernameAvailabilityUseCase: CheckUsernameAvailabilityUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(username: String) async throws -> Bool {
        try await repository.checkUsernameAvailability(username)
    }
}
