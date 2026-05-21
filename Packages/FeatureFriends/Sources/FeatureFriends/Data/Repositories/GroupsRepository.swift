import Foundation
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
