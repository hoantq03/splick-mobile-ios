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

    public func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult {
        guard !userIds.isEmpty else {
            throw FriendsError.invalidInviteSelection
        }
        let response: InviteFriendsResponseDTO = try await apiClient.request(
            SocialEndpoint.inviteFriendsToGroup(groupId: groupId, userIds: userIds)
        )
        return InviteFriendsToGroupResult(invited: response.invited, skipped: response.skipped)
    }

    public func searchGroup(inviteCode: String) async throws -> Group? {
        throw FriendsError.notImplemented
    }

    public func joinGroup(inviteCode: String) async throws -> Group {
        throw FriendsError.notImplemented
    }

    public func joinGroupFromQRCode(_ payload: String) async throws -> Group {
        throw FriendsError.notImplemented
    }
}
