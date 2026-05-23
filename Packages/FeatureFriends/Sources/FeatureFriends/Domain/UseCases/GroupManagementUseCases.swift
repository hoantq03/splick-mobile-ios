import Foundation
import SplickDomain

public protocol FetchGroupUseCaseProtocol: Sendable {
    func execute(groupId: UUID) async throws -> Group
}

public struct FetchGroupUseCase: FetchGroupUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID) async throws -> Group {
        try await repository.fetchGroup(groupId: groupId)
    }
}

public protocol ApproveGroupMemberUseCaseProtocol: Sendable {
    func execute(groupId: UUID, memberRowId: UUID) async throws
}

public struct ApproveGroupMemberUseCase: ApproveGroupMemberUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, memberRowId: UUID) async throws {
        try await repository.approvePendingMember(groupId: groupId, memberRowId: memberRowId)
    }
}

public protocol RejectGroupMemberUseCaseProtocol: Sendable {
    func execute(groupId: UUID, memberRowId: UUID) async throws
}

public struct RejectGroupMemberUseCase: RejectGroupMemberUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, memberRowId: UUID) async throws {
        try await repository.rejectPendingMember(groupId: groupId, memberRowId: memberRowId)
    }
}

public protocol RemoveGroupMemberUseCaseProtocol: Sendable {
    func execute(groupId: UUID, memberRowId: UUID) async throws
}

public struct RemoveGroupMemberUseCase: RemoveGroupMemberUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, memberRowId: UUID) async throws {
        try await repository.removeMember(groupId: groupId, memberRowId: memberRowId)
    }
}

public protocol LeaveGroupUseCaseProtocol: Sendable {
    func execute(groupId: UUID) async throws
}

public struct LeaveGroupUseCase: LeaveGroupUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID) async throws {
        try await repository.leaveGroup(groupId: groupId)
    }
}

public protocol DeleteGroupUseCaseProtocol: Sendable {
    func execute(groupId: UUID) async throws
}

public struct DeleteGroupUseCase: DeleteGroupUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID) async throws {
        try await repository.deleteGroup(groupId: groupId)
    }
}
