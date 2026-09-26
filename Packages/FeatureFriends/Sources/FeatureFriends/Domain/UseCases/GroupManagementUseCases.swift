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

public protocol UpdateGroupUseCaseProtocol: Sendable {
    func execute(groupId: UUID, name: String, description: String?) async throws -> Group
}

public struct UpdateGroupUseCase: UpdateGroupUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, name: String, description: String?) async throws -> Group {
        try await repository.updateGroup(groupId: groupId, name: name, description: description)
    }
}

public protocol UpdateGroupAvatarUseCaseProtocol: Sendable {
    func execute(groupId: UUID, avatarURL: String) async throws -> Group
}

public struct UpdateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, avatarURL: String) async throws -> Group {
        try await repository.updateGroupAvatar(groupId: groupId, avatarURL: avatarURL)
    }
}

public protocol TransferGroupOwnershipUseCaseProtocol: Sendable {
    func execute(groupId: UUID, newOwnerId: UUID) async throws -> Group
}

public struct TransferGroupOwnershipUseCase: TransferGroupOwnershipUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, newOwnerId: UUID) async throws -> Group {
        try await repository.transferOwnership(groupId: groupId, newOwnerId: newOwnerId)
    }
}

public protocol GenerateGroupQrUseCaseProtocol: Sendable {
    func execute(groupId: UUID, ttlSeconds: Int?) async throws -> GroupServerQR
}

public struct GenerateGroupQrUseCase: GenerateGroupQrUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, ttlSeconds: Int? = 86_400) async throws -> GroupServerQR {
        try await repository.generateGroupQr(groupId: groupId, ttlSeconds: ttlSeconds)
    }
}

public protocol RevokeGroupQrUseCaseProtocol: Sendable {
    func execute(groupId: UUID, qrId: UUID) async throws
}

public struct RevokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, qrId: UUID) async throws {
        try await repository.revokeGroupQr(groupId: groupId, qrId: qrId)
    }
}
