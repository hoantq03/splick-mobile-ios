import Foundation
import SplickDomain

public struct GroupInviteCode: Sendable, Equatable {
    public let id: UUID
    public let code: String
    public let groupId: UUID
    public let issuedAt: Date
    public let expiresAt: Date?

    public init(id: UUID, code: String, groupId: UUID, issuedAt: Date, expiresAt: Date?) {
        self.id = id
        self.code = code
        self.groupId = groupId
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }
}

public struct InviteFriendsToGroupResult: Sendable, Equatable {
    public let invited: [UUID]
    public let skipped: [UUID]

    public init(invited: [UUID], skipped: [UUID]) {
        self.invited = invited
        self.skipped = skipped
    }
}

public protocol GroupsRepositoryProtocol: Sendable {
    func fetchMyGroups() async throws -> [Group]
    func createGroup(name: String, description: String?) async throws -> Group
    func fetchActiveInviteCode(groupId: UUID) async throws -> GroupInviteCode?
    func generateInviteCode(groupId: UUID) async throws -> GroupInviteCode
    func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult
    func searchGroup(inviteCode: String) async throws -> Group?
    func joinGroup(inviteCode: String) async throws -> Group
    func joinGroupFromQRCode(_ payload: String) async throws -> Group
}
