import Foundation
import Common
import Networking
import SplickDomain

public struct GroupsRepository: GroupsRepositoryProtocol {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchMyGroups() async throws -> [Group] {
        let response: SocialPageGroupSummaryResponseDTO = try await apiClient.request(
            SocialEndpoint.listMyGroups(page: 0, size: 100)
        )
        return response.content.map(FriendsMapper.toGroup)
    }

    public func fetchGroup(groupId: UUID) async throws -> Group {
        let response: GroupResponseDTO = try await apiClient.request(
            SocialEndpoint.getGroup(groupId: groupId)
        )
        return FriendsMapper.toGroup(response)
    }

    public func fetchGroupMembers(groupId: UUID, status: String? = "ACTIVE") async throws -> [GroupMemberItem] {
        let response: SocialPageMemberResponseDTO = try await apiClient.request(
            SocialEndpoint.listGroupMembers(groupId: groupId, status: status, page: 0, size: 100)
        )
        return response.content.map(FriendsMapper.toGroupMemberItem)
    }

    public func createGroup(name: String, description: String?) async throws -> Group {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FriendsError.invalidGroupName
        }

        let trimmedDescription = description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyDescription = (trimmedDescription?.isEmpty == false) ? trimmedDescription : nil

        let response: GroupResponseDTO = try await apiClient.request(
            SocialEndpoint.createGroup(name: trimmedName, description: bodyDescription)
        )
        return FriendsMapper.toGroup(response)
    }

    public func updateGroup(groupId: UUID, name: String, description: String?) async throws -> Group {
        let response: GroupResponseDTO = try await apiClient.request(
            SocialEndpoint.updateGroup(groupId: groupId, name: name, description: description)
        )
        return FriendsMapper.toGroup(response)
    }

    public func updateGroupAvatar(groupId: UUID, avatarURL: String) async throws -> Group {
        let response: GroupResponseDTO = try await apiClient.request(
            SocialEndpoint.updateGroupAvatar(groupId: groupId, avatarURL: avatarURL)
        )
        return FriendsMapper.toGroup(response)
    }

    public func deleteGroup(groupId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.deleteGroup(groupId: groupId))
    }

    public func fetchActiveInviteCode(groupId: UUID) async throws -> GroupInviteCode? {
        do {
            let response: InviteCodeResponseDTO = try await apiClient.request(
                SocialEndpoint.getActiveGroupInviteCode(groupId: groupId)
            )
            return FriendsMapper.toGroupInviteCode(response)
        } catch let error as NetworkError where error == .notFound {
            return nil
        }
    }

    public func generateInviteCode(groupId: UUID) async throws -> GroupInviteCode {
        let response: InviteCodeResponseDTO = try await apiClient.request(
            SocialEndpoint.generateGroupInviteCode(groupId: groupId)
        )
        return FriendsMapper.toGroupInviteCode(response)
    }

    public func revokeInviteCode(groupId: UUID, invitationId: UUID) async throws {
        try await apiClient.request(
            SocialEndpoint.revokeGroupInviteCode(groupId: groupId, invitationId: invitationId)
        )
    }

    public func generateGroupQr(groupId: UUID, ttlSeconds: Int?) async throws -> GroupServerQR {
        let response: GroupQRResponseDTO = try await apiClient.request(
            SocialEndpoint.generateGroupQr(groupId: groupId, ttlSeconds: ttlSeconds)
        )
        return GroupServerQR(
            id: response.id,
            payload: response.payload,
            groupId: response.groupId,
            issuedAt: response.issuedAt,
            expiresAt: response.expiresAt
        )
    }

    public func revokeGroupQr(groupId: UUID, qrId: UUID) async throws {
        try await apiClient.request(
            SocialEndpoint.revokeGroupQr(groupId: groupId, qrId: qrId)
        )
    }

    public func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult {
        guard !userIds.isEmpty else {
            throw FriendsError.invalidInviteSelection
        }
        let response: InviteFriendsResponseDTO = try await apiClient.request(
            SocialEndpoint.inviteFriendsToGroup(groupId: groupId, userIds: userIds)
        )
        return InviteFriendsToGroupResult(invited: response.invited, skipped: response.skipped)
    }

    public func joinGroup(inviteCode: String) async throws -> Group {
        let normalized = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count >= 8 else {
            throw FriendsError.invalidQRCode
        }
        let joinResponse: JoinGroupResponseDTO = try await apiClient.request(
            SocialEndpoint.joinGroupByCode(code: normalized)
        )
        return try await fetchGroup(groupId: joinResponse.groupId)
    }

    public func joinGroupFromQRCode(_ payload: String) async throws -> Group {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if let action = SplickQRParser.parse(trimmed), case .joinGroup(let code) = action {
            return try await joinGroup(inviteCode: code)
        }
        let joinResponse: JoinGroupResponseDTO = try await apiClient.request(
            SocialEndpoint.joinGroupByQr(qrPayload: trimmed)
        )
        return try await fetchGroup(groupId: joinResponse.groupId)
    }

    public func approvePendingMember(groupId: UUID, memberRowId: UUID) async throws {
        let _: MemberResponseDTO = try await apiClient.request(
            SocialEndpoint.approveGroupMember(groupId: groupId, memberRowId: memberRowId)
        )
    }

    public func rejectPendingMember(groupId: UUID, memberRowId: UUID) async throws {
        try await apiClient.request(
            SocialEndpoint.rejectGroupMember(groupId: groupId, memberRowId: memberRowId)
        )
    }

    public func removeMember(groupId: UUID, memberRowId: UUID) async throws {
        try await apiClient.request(
            SocialEndpoint.removeGroupMember(groupId: groupId, memberRowId: memberRowId)
        )
    }

    public func leaveGroup(groupId: UUID) async throws {
        try await apiClient.request(SocialEndpoint.leaveGroup(groupId: groupId))
    }

    public func transferOwnership(groupId: UUID, newOwnerId: UUID) async throws -> Group {
        let response: GroupResponseDTO = try await apiClient.request(
            SocialEndpoint.transferGroupOwnership(groupId: groupId, newOwnerId: newOwnerId)
        )
        return FriendsMapper.toGroup(response)
    }
}
