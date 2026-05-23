import Foundation
import Common
import SplickDomain
import FeatureSocialFeed
import FeatureFriends

/// Offline stub for groups only. User search/friends always come from the backend API.
public actor FakeFriendsRepository: FriendsRepositoryProtocol, FriendsManagementRepositoryProtocol, GroupsRepositoryProtocol {
    private var groups: [Group] = []
    private let logger: StateLogger

    private let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        let me = UserSummary(
            id: currentUserId,
            username: "devuser",
            displayName: "Dev User",
            avatarURL: nil
        )

        groups = [
            Group(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "Roommates Q7",
                inviteCode: "roommates-q7",
                description: "Apartment shared costs",
                members: [me],
                createdBy: currentUserId
            ),
        ]

        logger.log("Seeded \(groups.count) mock groups (users via API/DB)")
    }

    // MARK: - Mention search (offline: empty — use live API in the app)

    public func fetchFriends(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        _ = query
        _ = page
        _ = limit
        return []
    }

    // MARK: - Friends management (offline: empty)

    public func fetchMyFriends() async throws -> [UserSummary] { [] }

    public func searchUsers(query: String, page: Int, size: Int) async throws -> [UserSearchResult] {
        _ = query
        _ = page
        _ = size
        return []
    }

    public func searchUser(username: String) async throws -> UserSummary? {
        _ = username
        return nil
    }

    public func addFriend(username: String, message: String?) async throws -> UserSummary {
        _ = username
        _ = message
        throw FriendsError.notImplemented
    }

    public func fetchIncomingFriendRequests(page: Int, size: Int) async throws -> [IncomingFriendRequest] {
        _ = page
        _ = size
        return []
    }

    public func fetchAllIncomingFriendRequests() async throws -> [IncomingFriendRequest] {
        []
    }

    public func acceptFriendRequest(requestId: UUID) async throws {
        _ = requestId
        throw FriendsError.notImplemented
    }

    public func rejectFriendRequest(requestId: UUID) async throws {
        _ = requestId
        throw FriendsError.notImplemented
    }

    public func cancelFriendRequest(requestId: UUID) async throws {
        _ = requestId
        throw FriendsError.notImplemented
    }

    public func fetchOutgoingFriendRequests(page: Int, size: Int) async throws -> [OutgoingFriendRequest] {
        _ = page
        _ = size
        return []
    }

    public func fetchAllOutgoingFriendRequests() async throws -> [OutgoingFriendRequest] {
        []
    }

    public func removeFriend(friendUserId: UUID) async throws {
        _ = friendUserId
        throw FriendsError.notImplemented
    }

    public func setFriendNickname(friendUserId: UUID, nickname: String?) async throws -> UserSummary {
        _ = friendUserId
        _ = nickname
        throw FriendsError.notImplemented
    }

    public func fetchBlockedUsers(page: Int, size: Int) async throws -> [BlockedUser] {
        _ = page
        _ = size
        return []
    }

    public func fetchAllBlockedUsers() async throws -> [BlockedUser] {
        []
    }

    public func blockUser(userId: UUID) async throws {
        _ = userId
        throw FriendsError.notImplemented
    }

    public func unblockUser(userId: UUID) async throws {
        _ = userId
        throw FriendsError.notImplemented
    }

    public func addFriendFromQRCode(_ payload: String) async throws -> UserSummary {
        throw FriendsError.notImplemented
    }

    public func generateMyQr() async throws -> PersonalQRCode {
        throw FriendsError.notImplemented
    }

    public func revokeMyQr() async throws {
        throw FriendsError.notImplemented
    }

    // MARK: - Groups

    public func fetchMyGroups() async throws -> [Group] {
        try await Task.sleep(for: .milliseconds(150))
        return groups.filter { group in
            group.createdBy == currentUserId
                || group.members.contains { $0.id == currentUserId }
        }
    }

    public func createGroup(name: String, description: String?) async throws -> Group {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FriendsError.invalidGroupName }

        let me = UserSummary(
            id: currentUserId,
            username: "devuser",
            displayName: "Dev User",
            avatarURL: nil
        )
        let group = Group(
            id: UUID(),
            name: trimmed,
            inviteCode: "",
            description: description,
            members: [me],
            memberCount: 1,
            createdBy: currentUserId
        )
        groups.append(group)
        logger.log("Created mock group \(trimmed)")
        return group
    }

    public func fetchGroup(groupId: UUID) async throws -> Group {
        guard let group = groups.first(where: { $0.id == groupId }) else {
            throw FriendsError.groupNotFound
        }
        return group
    }

    public func fetchGroupMembers(groupId: UUID, status: String?) async throws -> [GroupMemberItem] {
        guard let group = groups.first(where: { $0.id == groupId }) else { return [] }
        return group.members.enumerated().map { index, user in
            GroupMemberItem(
                id: UUID(),
                userId: user.id,
                username: user.username,
                displayName: user.displayName,
                avatarURL: user.avatarURL,
                role: user.id == group.createdBy ? "OWNER" : "MEMBER",
                status: status?.uppercased() ?? "ACTIVE"
            )
        }
    }

    public func updateGroup(groupId: UUID, name: String, description: String?) async throws -> Group {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else {
            throw FriendsError.groupNotFound
        }
        var group = groups[index]
        group = Group(
            id: group.id,
            name: name,
            inviteCode: group.inviteCode,
            description: description,
            avatarURL: group.avatarURL,
            members: group.members,
            memberCount: group.memberCount,
            createdBy: group.createdBy,
            createdAt: group.createdAt
        )
        groups[index] = group
        return group
    }

    public func updateGroupAvatar(groupId: UUID, avatarURL: String) async throws -> Group {
        try await fetchGroup(groupId: groupId)
    }

    public func deleteGroup(groupId: UUID) async throws {
        groups.removeAll { $0.id == groupId }
    }

    public func revokeInviteCode(groupId: UUID, invitationId: UUID) async throws {}

    public func generateGroupQr(groupId: UUID, ttlSeconds: Int?) async throws -> GroupServerQR {
        let payload = SplickQRParser.groupPayload(
            inviteCode: groups.first { $0.id == groupId }?.inviteCode ?? "MOCKCODE1"
        )
        return GroupServerQR(
            id: UUID(),
            payload: payload,
            groupId: groupId,
            issuedAt: .now,
            expiresAt: .now.addingTimeInterval(86_400)
        )
    }

    public func revokeGroupQr(groupId: UUID, qrId: UUID) async throws {}

    public func approvePendingMember(groupId: UUID, memberRowId: UUID) async throws {}

    public func rejectPendingMember(groupId: UUID, memberRowId: UUID) async throws {}

    public func removeMember(groupId: UUID, memberRowId: UUID) async throws {}

    public func leaveGroup(groupId: UUID) async throws {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        var group = groups[index]
        group = Group(
            id: group.id,
            name: group.name,
            inviteCode: group.inviteCode,
            description: group.description,
            avatarURL: group.avatarURL,
            members: group.members.filter { $0.id != currentUserId },
            memberCount: max(0, group.memberCount - 1),
            createdBy: group.createdBy,
            createdAt: group.createdAt
        )
        groups[index] = group
    }

    public func transferOwnership(groupId: UUID, newOwnerId: UUID) async throws -> Group {
        try await fetchGroup(groupId: groupId)
    }

    public func fetchActiveInviteCode(groupId: UUID) async throws -> GroupInviteCode? {
        guard let group = groups.first(where: { $0.id == groupId }) else { return nil }
        let code = group.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        return GroupInviteCode(
            id: UUID(),
            code: code,
            groupId: groupId,
            issuedAt: .now,
            expiresAt: nil
        )
    }

    public func generateInviteCode(groupId: UUID) async throws -> GroupInviteCode {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else {
            throw FriendsError.groupNotFound
        }
        let code = "MOCK\(String(groups[index].name.prefix(4)).uppercased())"
        var group = groups[index]
        group = Group(
            id: group.id,
            name: group.name,
            inviteCode: code,
            description: group.description,
            avatarURL: group.avatarURL,
            members: group.members,
            memberCount: group.memberCount,
            createdBy: group.createdBy,
            createdAt: group.createdAt
        )
        groups[index] = group
        return GroupInviteCode(
            id: UUID(),
            code: code,
            groupId: groupId,
            issuedAt: .now,
            expiresAt: nil
        )
    }

    public func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult {
        InviteFriendsToGroupResult(invited: userIds, skipped: [])
    }

    public func joinGroup(inviteCode: String) async throws -> Group {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let index = groups.firstIndex(where: { $0.inviteCode.lowercased() == code }) else {
            throw FriendsError.groupNotFound
        }

        var group = groups[index]
        let me = UserSummary(
            id: currentUserId,
            username: "devuser",
            displayName: "Dev User",
            avatarURL: nil
        )

        if group.members.contains(where: { $0.id == currentUserId }) {
            throw FriendsError.alreadyInGroup
        }

        var members = group.members
        members.append(me)
        group = Group(
            id: group.id,
            name: group.name,
            inviteCode: group.inviteCode,
            description: group.description,
            avatarURL: group.avatarURL,
            members: members,
            createdBy: group.createdBy,
            createdAt: group.createdAt
        )
        groups[index] = group
        logger.log("Joined group \(group.name)")
        return group
    }

    public func joinGroupFromQRCode(_ payload: String) async throws -> Group {
        guard case .joinGroup(let inviteCode) = SplickQRParser.parse(payload) else {
            throw FriendsError.invalidQRCode
        }
        return try await joinGroup(inviteCode: inviteCode)
    }
}
