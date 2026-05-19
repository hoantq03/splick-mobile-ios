import Foundation
import SplickDomain

public protocol GetConnectedAccountsUseCaseProtocol: Sendable {
    func execute() async throws -> ConnectedAccounts
}

public final class GetConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> ConnectedAccounts {
        try await repository.getConnectedAccounts()
    }
}
