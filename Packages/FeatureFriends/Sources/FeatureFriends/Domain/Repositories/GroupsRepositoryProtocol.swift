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
    func fetchGroup(groupId: UUID) async throws -> Group
    func fetchGroupMembers(groupId: UUID, status: String?) async throws -> [GroupMemberItem]
    func createGroup(name: String, description: String?) async throws -> Group
    func updateGroup(groupId: UUID, name: String, description: String?) async throws -> Group
    func updateGroupAvatar(groupId: UUID, avatarURL: String) async throws -> Group
    func deleteGroup(groupId: UUID) async throws
    func fetchActiveInviteCode(groupId: UUID) async throws -> GroupInviteCode?
    func generateInviteCode(groupId: UUID) async throws -> GroupInviteCode
    func revokeInviteCode(groupId: UUID, invitationId: UUID) async throws
    func generateGroupQr(groupId: UUID, ttlSeconds: Int?) async throws -> String
    func revokeGroupQr(groupId: UUID, qrId: UUID) async throws
    func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult
    func joinGroup(inviteCode: String) async throws -> Group
    func joinGroupFromQRCode(_ payload: String) async throws -> Group
    func approvePendingMember(groupId: UUID, memberRowId: UUID) async throws
    func rejectPendingMember(groupId: UUID, memberRowId: UUID) async throws
    func removeMember(groupId: UUID, memberRowId: UUID) async throws
    func leaveGroup(groupId: UUID) async throws
    func transferOwnership(groupId: UUID, newOwnerId: UUID) async throws -> Group
}
