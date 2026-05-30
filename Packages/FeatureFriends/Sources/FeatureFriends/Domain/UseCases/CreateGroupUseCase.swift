import Foundation
import SplickDomain

public protocol CreateGroupUseCaseProtocol: Sendable {
    func execute(name: String, description: String?) async throws -> Group
}

public struct CreateGroupUseCase: CreateGroupUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(name: String, description: String?) async throws -> Group {
        try await repository.createGroup(name: name, description: description)
    }
}
