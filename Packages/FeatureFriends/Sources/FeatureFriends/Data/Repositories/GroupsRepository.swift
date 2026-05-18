import Foundation
import SplickDomain

public struct GroupsRepository: GroupsRepositoryProtocol {
    public init() {}

    public func fetchMyGroups() async throws -> [Group] { [] }

    public func searchGroup(inviteCode: String) async throws -> Group? { nil }

    public func joinGroup(inviteCode: String) async throws -> Group {
        throw FriendsError.notImplemented
    }

    public func joinGroupFromQRCode(_ payload: String) async throws -> Group {
        throw FriendsError.notImplemented
    }
}
