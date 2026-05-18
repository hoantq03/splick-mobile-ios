import Foundation
import Common
import SplickDomain
import FeatureSocialFeed
import FeatureFriends

public actor FakeFriendsRepository: FriendsRepositoryProtocol, FriendsManagementRepositoryProtocol, GroupsRepositoryProtocol {
    private var myFriends: [UserSummary] = []
    private var directory: [UserSummary] = []
    private var groups: [Group] = []
    private let logger: StateLogger

    private let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        let core: [UserSummary] = [
            UserSummary(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                username: "linhpham",
                displayName: "Linh Pham",
                avatarURL: nil
            ),
            UserSummary(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                username: "ducnguyen",
                displayName: "Duc Nguyen",
                avatarURL: nil
            ),
            UserSummary(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                username: "minhthu",
                displayName: "Minh Thu",
                avatarURL: nil
            ),
        ]

        let generated = (0..<48).map { index in
            UserSummary(
                id: UUID(),
                username: "friend\(index)",
                displayName: "Friend \(index + 1)",
                avatarURL: nil
            )
        }

        directory = core + generated
        myFriends = Array(core.prefix(3))

        let me = UserSummary(
            id: currentUserId,
            username: "namtran",
            displayName: "Nam Tran",
            avatarURL: nil
        )

        groups = [
            Group(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "Roommates Q7",
                inviteCode: "roommates-q7",
                description: "Apartment shared costs",
                members: [me] + Array(core.prefix(2)),
                createdBy: currentUserId
            ),
            Group(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: "Weekend Trip Đà Lạt",
                inviteCode: "dalat-trip",
                description: "Travel expenses",
                members: [me, core[2]],
                createdBy: core[2].id
            ),
            Group(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: "Office Lunch",
                inviteCode: "office-lunch",
                description: nil,
                members: [me, core[0], core[1], core[2]],
                createdBy: core[0].id
            ),
            Group(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                name: "Study Club",
                inviteCode: "study-club",
                description: "Join to split study materials",
                members: [core[1], core[2]],
                createdBy: core[1].id
            ),
        ]

        logger.log("Seeded \(myFriends.count) friends, \(directory.count) directory users, \(groups.count) groups")
    }

    // MARK: - Mention / search (FeatureSocialFeed)

    public func fetchFriends(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        try await Task.sleep(for: .milliseconds(120))

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [UserSummary]
        if normalized.isEmpty {
            filtered = directory
        } else {
            filtered = directory.filter {
                $0.username.lowercased().contains(normalized)
                    || $0.displayName.lowercased().contains(normalized)
            }
        }

        let start = page * limit
        guard start < filtered.count else { return [] }
        let end = min(start + limit, filtered.count)
        return Array(filtered[start..<end])
    }

    // MARK: - Friends management

    public func fetchMyFriends() async throws -> [UserSummary] {
        try await Task.sleep(for: .milliseconds(150))
        return myFriends
    }

    public func searchUser(username: String) async throws -> UserSummary? {
        let normalized = normalizeUsername(username)
        return directory.first { $0.username.lowercased() == normalized }
    }

    public func addFriend(username: String) async throws -> UserSummary {
        let normalized = normalizeUsername(username)
        guard let user = directory.first(where: { $0.username.lowercased() == normalized }) else {
            throw FriendsError.userNotFound
        }
        guard user.id != currentUserId else {
            throw FriendsError.userNotFound
        }
        guard !myFriends.contains(where: { $0.id == user.id }) else {
            throw FriendsError.alreadyFriends
        }
        myFriends.append(user)
        logger.log("Added friend @\(user.username)")
        return user
    }

    public func addFriendFromQRCode(_ payload: String) async throws -> UserSummary {
        guard case .addFriend(let username) = SplickQRParser.parse(payload) else {
            throw FriendsError.invalidQRCode
        }
        return try await addFriend(username: username)
    }

    // MARK: - Groups

    public func fetchMyGroups() async throws -> [Group] {
        try await Task.sleep(for: .milliseconds(150))
        return groups.filter { group in
            group.members.contains { $0.id == currentUserId }
        }
    }

    public func searchGroup(inviteCode: String) async throws -> Group? {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return groups.first { $0.inviteCode.lowercased() == code }
    }

    public func joinGroup(inviteCode: String) async throws -> Group {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let index = groups.firstIndex(where: { $0.inviteCode.lowercased() == code }) else {
            throw FriendsError.groupNotFound
        }

        var group = groups[index]
        let me = UserSummary(
            id: currentUserId,
            username: "namtran",
            displayName: "Nam Tran",
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

    private func normalizeUsername(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
    }
}
