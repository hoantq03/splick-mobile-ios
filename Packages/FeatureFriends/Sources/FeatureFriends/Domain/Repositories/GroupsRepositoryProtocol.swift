import Foundation
import SplickDomain

public protocol GroupsRepositoryProtocol: Sendable {
    func fetchMyGroups() async throws -> [Group]
    func searchGroup(inviteCode: String) async throws -> Group?
    func joinGroup(inviteCode: String) async throws -> Group
    func joinGroupFromQRCode(_ payload: String) async throws -> Group
}
