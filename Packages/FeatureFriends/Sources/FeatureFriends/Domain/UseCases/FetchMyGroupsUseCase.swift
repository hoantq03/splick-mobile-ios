import Foundation
import SplickDomain

public protocol FetchMyGroupsUseCaseProtocol: Sendable {
    func execute() async throws -> [Group]
}

public struct FetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [Group] {
        try await repository.fetchMyGroups()
    }
}
