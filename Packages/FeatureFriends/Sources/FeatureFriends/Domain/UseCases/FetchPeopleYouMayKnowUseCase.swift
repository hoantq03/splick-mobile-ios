import Foundation
import SplickDomain

/// Preloaded social directory used to avoid re-fetching the same lists for PYMK.
public struct PeopleYouMayKnowDirectorySnapshot: Sendable {
    public let friends: [UserSummary]
    public let groups: [Group]
    public let incoming: [IncomingFriendRequest]
    public let outgoing: [OutgoingFriendRequest]
    public let blocked: [BlockedUser]

    public init(
        friends: [UserSummary],
        groups: [Group],
        incoming: [IncomingFriendRequest],
        outgoing: [OutgoingFriendRequest],
        blocked: [BlockedUser]
    ) {
        self.friends = friends
        self.groups = groups
        self.incoming = incoming
        self.outgoing = outgoing
        self.blocked = blocked
    }
}

public protocol FetchPeopleYouMayKnowUseCaseProtocol: Sendable {
    func execute(
        currentUserId: UUID?,
        snapshot: PeopleYouMayKnowDirectorySnapshot?
    ) async throws -> [PeopleYouMayKnowSuggestion]
}

public struct FetchPeopleYouMayKnowUseCase: FetchPeopleYouMayKnowUseCaseProtocol {
    private static let maxGroupsToScan = 12
    private static let maxSuggestions = 40

    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol
    private let fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    private let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    private let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private let fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol

    public init(
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol,
        fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol
    ) {
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.fetchGroupMembersUseCase = fetchGroupMembersUseCase
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
        self.fetchOutgoingFriendRequestsUseCase = fetchOutgoingFriendRequestsUseCase
        self.fetchBlockedUsersUseCase = fetchBlockedUsersUseCase
    }

    public func execute(
        currentUserId: UUID?,
        snapshot: PeopleYouMayKnowDirectorySnapshot? = nil
    ) async throws -> [PeopleYouMayKnowSuggestion] {
        let directory: PeopleYouMayKnowDirectorySnapshot
        if let snapshot {
            directory = snapshot
        } else {
            async let groupsTask = fetchMyGroupsUseCase.execute()
            async let friendsTask = fetchMyFriendsUseCase.execute()
            async let incomingTask = fetchIncomingFriendRequestsUseCase.executeAll()
            async let outgoingTask = fetchOutgoingFriendRequestsUseCase.executeAll()
            async let blockedTask = fetchBlockedUsersUseCase.executeAll()

            let (groups, friends, incoming, outgoing, blocked) = try await (
                groupsTask,
                friendsTask,
                incomingTask,
                outgoingTask,
                blockedTask
            )
            directory = PeopleYouMayKnowDirectorySnapshot(
                friends: friends,
                groups: groups,
                incoming: incoming,
                outgoing: outgoing,
                blocked: blocked
            )
        }

        let friendIds = Set(directory.friends.map(\.id))
        let blockedIds = Set(directory.blocked.map(\.user.id))
        let incomingByUserId = Dictionary(
            uniqueKeysWithValues: directory.incoming.map { ($0.requester.id, $0) }
        )
        let outgoingByUserId = Dictionary(
            uniqueKeysWithValues: directory.outgoing.map { ($0.addressee.id, $0) }
        )

        var suggestionsByUserId: [UUID: PeopleYouMayKnowSuggestion] = [:]

        for group in directory.groups.prefix(Self.maxGroupsToScan) {
            let members: [GroupMemberItem]
            do {
                members = try await fetchGroupMembersUseCase.execute(groupId: group.id, status: "ACTIVE")
            } catch {
                continue
            }

            for member in members where !member.isPending {
                let userId = member.userId
                guard userId != currentUserId else { continue }
                guard !friendIds.contains(userId) else { continue }
                guard !blockedIds.contains(userId) else { continue }
                guard incomingByUserId[userId] == nil else { continue }
                guard outgoingByUserId[userId] == nil else { continue }

                let user = UserSummary(
                    id: userId,
                    username: member.username,
                    displayName: member.displayName,
                    avatarURL: member.avatarURL
                )

                if let existing = suggestionsByUserId[userId] {
                    if existing.sharedGroupName == nil {
                        suggestionsByUserId[userId] = PeopleYouMayKnowSuggestion(
                            user: user,
                            friendStatus: .none,
                            sharedGroupName: group.name
                        )
                    }
                } else {
                    suggestionsByUserId[userId] = PeopleYouMayKnowSuggestion(
                        user: user,
                        friendStatus: .none,
                        sharedGroupName: group.name
                    )
                }
            }
        }

        return suggestionsByUserId.values
            .sorted {
                $0.user.displayName.localizedCaseInsensitiveCompare($1.user.displayName) == .orderedAscending
            }
            .prefix(Self.maxSuggestions)
            .map { $0 }
    }
}
