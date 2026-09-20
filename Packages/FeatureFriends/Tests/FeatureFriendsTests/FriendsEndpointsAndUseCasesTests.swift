import XCTest
import SplickDomain
import Common
import Networking
@testable import FeatureFriends

final class FriendsEndpointsAndUseCasesTests: XCTestCase {

    // MARK: - SocialEndpoint Tests

    func testSocialEndpoint_pathsAndMethods() {
        let dummyId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let dummyGroupId = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        let dummyMemberId = UUID(uuidString: "33333333-4444-5555-6666-777777777777")!

        // Paths
        XCTAssertEqual(SocialEndpoint.getUserProfile(userId: dummyId).path, "/v1/social/users/\(dummyId)")
        XCTAssertEqual(SocialEndpoint.getFriendPaymentProfile(userId: dummyId).path, "/v1/social/users/\(dummyId)/payment-profile")
        XCTAssertEqual(SocialEndpoint.searchUsers(query: "q", page: 0, size: 20).path, "/v1/social/users/search")
        XCTAssertEqual(SocialEndpoint.listFriends(page: 0, size: 20).path, "/v1/social/friendships")
        XCTAssertEqual(SocialEndpoint.sendFriendRequest(username: "u", message: nil).path, "/v1/social/friendships/requests")
        XCTAssertEqual(SocialEndpoint.sendFriendRequestByQr(qrPayload: "p", message: nil).path, "/v1/social/friendships/requests/qr")
        XCTAssertEqual(SocialEndpoint.listIncomingFriendRequests(page: 0, size: 20).path, "/v1/social/friendships/requests/incoming")
        XCTAssertEqual(SocialEndpoint.listOutgoingFriendRequests(page: 0, size: 20).path, "/v1/social/friendships/requests/outgoing")
        XCTAssertEqual(SocialEndpoint.acceptFriendRequest(requestId: dummyId).path, "/v1/social/friendships/requests/\(dummyId)/accept")
        XCTAssertEqual(SocialEndpoint.rejectFriendRequest(requestId: dummyId).path, "/v1/social/friendships/requests/\(dummyId)/reject")
        XCTAssertEqual(SocialEndpoint.cancelFriendRequest(requestId: dummyId).path, "/v1/social/friendships/requests/\(dummyId)")
        XCTAssertEqual(SocialEndpoint.removeFriend(friendUserId: dummyId).path, "/v1/social/friendships/\(dummyId)")
        XCTAssertEqual(SocialEndpoint.setFriendNickname(friendUserId: dummyId, nickname: "nick").path, "/v1/social/friendships/\(dummyId)/nickname")
        XCTAssertEqual(SocialEndpoint.listBlockedUsers(page: 0, size: 20).path, "/v1/social/blocks")
        XCTAssertEqual(SocialEndpoint.blockUser(userId: dummyId).path, "/v1/social/blocks")
        XCTAssertEqual(SocialEndpoint.unblockUser(userId: dummyId).path, "/v1/social/blocks/\(dummyId)")

        // Groups
        XCTAssertEqual(SocialEndpoint.listMyGroups(page: 0, size: 20).path, "/v1/social/groups")
        XCTAssertEqual(SocialEndpoint.createGroup(name: "G", description: nil).path, "/v1/social/groups")
        XCTAssertEqual(SocialEndpoint.getGroup(groupId: dummyGroupId).path, "/v1/social/groups/\(dummyGroupId)")
        XCTAssertEqual(SocialEndpoint.updateGroup(groupId: dummyGroupId, name: "G", description: nil).path, "/v1/social/groups/\(dummyGroupId)")
        XCTAssertEqual(SocialEndpoint.updateGroupAvatar(groupId: dummyGroupId, avatarURL: "u").path, "/v1/social/groups/\(dummyGroupId)/avatar")
        XCTAssertEqual(SocialEndpoint.deleteGroup(groupId: dummyGroupId).path, "/v1/social/groups/\(dummyGroupId)")
        XCTAssertEqual(SocialEndpoint.joinGroupByCode(code: "C").path, "/v1/social/groups/join")
        XCTAssertEqual(SocialEndpoint.joinGroupByQr(qrPayload: "Q").path, "/v1/social/groups/join/qr")
        XCTAssertEqual(SocialEndpoint.listGroupMembers(groupId: dummyGroupId, status: nil, page: 0, size: 20).path, "/v1/social/groups/\(dummyGroupId)/members")
        XCTAssertEqual(SocialEndpoint.getActiveGroupInviteCode(groupId: dummyGroupId).path, "/v1/social/groups/\(dummyGroupId)/invite-codes/active")
        XCTAssertEqual(SocialEndpoint.generateGroupInviteCode(groupId: dummyGroupId).path, "/v1/social/groups/\(dummyGroupId)/invite-codes")
        XCTAssertEqual(SocialEndpoint.revokeGroupInviteCode(groupId: dummyGroupId, invitationId: dummyId).path, "/v1/social/groups/\(dummyGroupId)/invite-codes/\(dummyId)")
        XCTAssertEqual(SocialEndpoint.generateGroupQr(groupId: dummyGroupId, ttlSeconds: 300).path, "/v1/social/groups/\(dummyGroupId)/qr")
        XCTAssertEqual(SocialEndpoint.revokeGroupQr(groupId: dummyGroupId, qrId: dummyId).path, "/v1/social/groups/\(dummyGroupId)/qr/\(dummyId)")
        XCTAssertEqual(SocialEndpoint.inviteFriendsToGroup(groupId: dummyGroupId, userIds: [dummyId]).path, "/v1/social/groups/\(dummyGroupId)/members/invite")
        XCTAssertEqual(SocialEndpoint.approveGroupMember(groupId: dummyGroupId, memberRowId: dummyMemberId).path, "/v1/social/groups/\(dummyGroupId)/members/\(dummyMemberId)/approve")
        XCTAssertEqual(SocialEndpoint.rejectGroupMember(groupId: dummyGroupId, memberRowId: dummyMemberId).path, "/v1/social/groups/\(dummyGroupId)/members/\(dummyMemberId)/reject")
        XCTAssertEqual(SocialEndpoint.removeGroupMember(groupId: dummyGroupId, memberRowId: dummyMemberId).path, "/v1/social/groups/\(dummyGroupId)/members/\(dummyMemberId)")
        XCTAssertEqual(SocialEndpoint.leaveGroup(groupId: dummyGroupId).path, "/v1/social/groups/\(dummyGroupId)/membership")
        XCTAssertEqual(SocialEndpoint.transferGroupOwnership(groupId: dummyGroupId, newOwnerId: dummyId).path, "/v1/social/groups/\(dummyGroupId)/transfer-ownership")

        // Personal QR & Discovery
        XCTAssertEqual(SocialEndpoint.generateMyQr.path, "/v1/social/qr/me")
        XCTAssertEqual(SocialEndpoint.revokeMyQr.path, "/v1/social/qr/me")
        XCTAssertEqual(SocialEndpoint.bulkMessagingPresence(userIds: [dummyId]).path, "/v1/messaging/presence/bulk")
        XCTAssertEqual(SocialEndpoint.getDiscoveryPreference.path, "/v1/social/me/discovery")
        XCTAssertEqual(SocialEndpoint.updateDiscoveryPreference(nearbyEnabled: true).path, "/v1/social/me/discovery")
        XCTAssertEqual(SocialEndpoint.findNearbyUsers(lat: 10.5, lon: 106.5).path, "/v1/social/users/nearby")
        XCTAssertEqual(SocialEndpoint.leaveNearbySession.path, "/v1/social/users/nearby")

        // Methods
        XCTAssertEqual(SocialEndpoint.getUserProfile(userId: dummyId).method, .get)
        XCTAssertEqual(SocialEndpoint.searchUsers(query: "q", page: 0, size: 20).method, .get)
        XCTAssertEqual(SocialEndpoint.sendFriendRequest(username: "u", message: nil).method, .post)
        XCTAssertEqual(SocialEndpoint.acceptFriendRequest(requestId: dummyId).method, .post)
        XCTAssertEqual(SocialEndpoint.cancelFriendRequest(requestId: dummyId).method, .delete)
        XCTAssertEqual(SocialEndpoint.removeFriend(friendUserId: dummyId).method, .delete)
        XCTAssertEqual(SocialEndpoint.setFriendNickname(friendUserId: dummyId, nickname: nil).method, .patch)
        XCTAssertEqual(SocialEndpoint.unblockUser(userId: dummyId).method, .delete)
        XCTAssertEqual(SocialEndpoint.updateGroup(groupId: dummyGroupId, name: "G", description: nil).method, .patch)
        XCTAssertEqual(SocialEndpoint.deleteGroup(groupId: dummyGroupId).method, .delete)
        XCTAssertEqual(SocialEndpoint.updateDiscoveryPreference(nearbyEnabled: true).method, .patch)
        XCTAssertEqual(SocialEndpoint.leaveNearbySession.method, .delete)
        XCTAssertEqual(SocialEndpoint.findNearbyUsers(lat: 1, lon: 2).method, .post)

        // Query items
        let searchQuery = SocialEndpoint.searchUsers(query: "alice", page: 1, size: 10).queryItems
        XCTAssertTrue(searchQuery!.contains(where: { $0.name == "q" && $0.value == "alice" }))
        XCTAssertTrue(searchQuery!.contains(where: { $0.name == "page" && $0.value == "1" }))

        // Body
        XCTAssertNotNil(SocialEndpoint.createGroup(name: "G", description: "desc").body)
        XCTAssertNotNil(SocialEndpoint.updateDiscoveryPreference(nearbyEnabled: true).body)
        XCTAssertNotNil(SocialEndpoint.findNearbyUsers(lat: 10.5, lon: 106.5).body)
        XCTAssertNil(SocialEndpoint.generateMyQr.body)
    }

    // MARK: - FriendsMapper Tests

    func testFriendsMapper_conversions() {
        let userId = UUID()
        let now = Date()

        // toPublicUserProfile
        let profileDto = UserProfileResponseDTO(
            userId: userId,
            username: "hoan",
            displayName: "Hoan Tran",
            avatarUrl: "https://example.com/avatar.jpg",
            nickname: "Hoan",
            subtitle: "Hoan Tran",
            friendStatus: "FRIENDS",
            stats: UserProfileStatsResponseDTO(friendCount: 10, postCount: 5, groupCount: 2),
            online: true,
            lastSeenAt: now
        )
        let profile = FriendsMapper.toPublicUserProfile(profileDto)
        XCTAssertEqual(profile.user.id, userId)
        XCTAssertEqual(profile.user.displayName, "Hoan")
        XCTAssertEqual(profile.user.subtitle, "Hoan Tran")
        XCTAssertEqual(profile.friendStatus, FriendRelationStatus.friends)
        XCTAssertEqual(profile.stats.friendCount, 10)
        XCTAssertTrue(profile.isOnline)

        // toPaymentProfile
        let payDto = PaymentProfileResponseDTO(
            userId: userId,
            qrImageUrl: "https://example.com/qr.png",
            accountName: "TRAN QUOC HOAN",
            accountNumber: "123456789",
            bankName: "VCB",
            updatedAt: now
        )
        let pay = FriendsMapper.toPaymentProfile(payDto)
        XCTAssertEqual(pay.accountName, "TRAN QUOC HOAN")
        XCTAssertEqual(pay.bankName, "VCB")

        // toUserSearchResult
        let searchDto = UserSearchResponseDTO(
            userId: userId,
            username: "hoan",
            displayName: "Hoan",
            avatarUrl: nil,
            friendStatus: "REQUEST_SENT",
            distanceMeters: 150
        )
        let searchResult = FriendsMapper.toUserSearchResult(searchDto)
        XCTAssertEqual(searchResult.user.username, "hoan")
        XCTAssertEqual(searchResult.friendStatus, FriendRelationStatus.requestSent)
        XCTAssertEqual(searchResult.distanceMeters, 150)

        // toOutgoingFriendRequest
        let outgoingDto = FriendRequestResponseDTO(
            id: UUID(),
            requesterId: UUID(),
            addresseeId: userId,
            status: "PENDING",
            message: "Hello",
            createdAt: now,
            expiresAt: now.addingTimeInterval(86400),
            addresseeUsername: "bob",
            addresseeDisplayName: "Bob"
        )
        let outgoing = FriendsMapper.toOutgoingFriendRequest(outgoingDto)
        XCTAssertEqual(outgoing.addressee.displayName, "Bob")
        XCTAssertEqual(outgoing.message, "Hello")

        // toIncomingFriendRequest
        let incomingDto = IncomingFriendRequestResponseDTO(
            id: UUID(),
            requesterId: userId,
            requesterUsername: "alice",
            requesterDisplayName: "Alice",
            requesterAvatarUrl: nil,
            message: "Hi",
            createdAt: now,
            expiresAt: now.addingTimeInterval(86400)
        )
        let incoming = FriendsMapper.toIncomingFriendRequest(incomingDto)
        XCTAssertEqual(incoming.requester.username, "alice")
        XCTAssertEqual(incoming.message, "Hi")

        // toBlockedUser
        let blockedDto = BlockedUserResponseDTO(
            userId: userId,
            username: "bad_actor",
            displayName: "Bad Actor",
            blockedAt: now
        )
        let blocked = FriendsMapper.toBlockedUser(blockedDto)
        XCTAssertEqual(blocked.user.username, "bad_actor")
        XCTAssertEqual(blocked.blockedAt, now)

        // toGroup
        let groupDto = GroupResponseDTO(
            id: UUID(),
            name: "Best Friends",
            description: "Roommates group",
            avatarUrl: nil,
            ownerId: userId,
            createdAt: now
        )
        let group = FriendsMapper.toGroup(groupDto)
        XCTAssertEqual(group.name, "Best Friends")
        XCTAssertEqual(group.description, "Roommates group")

        // Presence state
        let presence = FriendsMapper.presenceState(from: profileDto)
        XCTAssertNotNil(presence)
        XCTAssertEqual(presence?.isOnline, true)
    }

    // MARK: - UseCases Tests

    func testFriendsUseCases_executions() async throws {
        let friendsRepo = MockFriendsManagementRepository()
        let groupsRepo = MockGroupsRepository()
        let dummyUserId = UUID()
        let dummyRequestId = UUID()
        let dummyGroupId = UUID()
        let dummyMemberId = UUID()

        // 1. FetchMyFriendsUseCase
        let fetchFriends = FetchMyFriendsUseCase(repository: friendsRepo)
        let friends = try await fetchFriends.execute()
        XCTAssertEqual(friends.count, 1)

        // 2. FetchUserProfileUseCase
        let fetchProfile = FetchUserProfileUseCase(repository: friendsRepo)
        let profile = try await fetchProfile.execute(userId: dummyUserId)
        XCTAssertEqual(profile.user.username, "hoan")

        // 3. FetchFriendPaymentProfileUseCase
        let fetchPayment = FetchFriendPaymentProfileUseCase(repository: friendsRepo)
        let payment = try await fetchPayment.execute(userId: dummyUserId)
        XCTAssertEqual(payment.bankName, "VCB")

        // 4. SearchUsersUseCase
        let search = SearchUsersUseCase(repository: friendsRepo)
        let results = try await search.execute(query: "hoan", page: 0, size: 10)
        XCTAssertEqual(results.count, 1)

        // 5. AddFriendUseCase
        let addFriend = AddFriendUseCase(repository: friendsRepo)
        let added = try await addFriend.execute(username: "hoan", message: "Hi")
        XCTAssertEqual(added.username, "hoan")

        // 6. FetchIncomingFriendRequestsUseCase
        let fetchIncoming = FetchIncomingFriendRequestsUseCase(repository: friendsRepo)
        let incoming = try await fetchIncoming.execute(page: 0, size: 10)
        XCTAssertEqual(incoming.count, 0)

        // 7. FetchOutgoingFriendRequestsUseCase
        let fetchOutgoing = FetchOutgoingFriendRequestsUseCase(repository: friendsRepo)
        let outgoing = try await fetchOutgoing.execute(page: 0, size: 10)
        XCTAssertEqual(outgoing.count, 0)

        // 8. AcceptFriendRequestUseCase
        let accept = AcceptFriendRequestUseCase(repository: friendsRepo)
        try await accept.execute(requestId: dummyRequestId)

        // 9. RejectFriendRequestUseCase
        let reject = RejectFriendRequestUseCase(repository: friendsRepo)
        try await reject.execute(requestId: dummyRequestId)

        // 10. CancelFriendRequestUseCase
        let cancel = CancelFriendRequestUseCase(repository: friendsRepo)
        try await cancel.execute(requestId: dummyRequestId)

        // 11. RemoveFriendUseCase
        let remove = RemoveFriendUseCase(repository: friendsRepo)
        try await remove.execute(friendUserId: dummyUserId)

        // 12. SetFriendNicknameUseCase
        let setNickname = SetFriendNicknameUseCase(repository: friendsRepo)
        let updated = try await setNickname.execute(friendUserId: dummyUserId, nickname: "Bro")
        XCTAssertEqual(updated.displayName, "Bro")

        // 13. FetchBlockedUsersUseCase
        let fetchBlocked = FetchBlockedUsersUseCase(repository: friendsRepo)
        let blocked = try await fetchBlocked.execute(page: 0, size: 10)
        XCTAssertEqual(blocked.count, 0)

        // 14. BlockUserUseCase & UnblockUserUseCase
        let block = BlockUserUseCase(repository: friendsRepo)
        try await block.execute(userId: dummyUserId)
        let unblock = UnblockUserUseCase(repository: friendsRepo)
        try await unblock.execute(userId: dummyUserId)

        // 15. GenerateMyQrUseCase
        let generateQr = GenerateMyQrUseCase(repository: friendsRepo)
        let myQr = try await generateQr.execute()
        XCTAssertEqual(myQr.payload, "splick://qr/hoan")

        // 16. NearbyDiscoveryUseCase
        let nearby = NearbyDiscoveryUseCase(repository: friendsRepo)
        let preference = try await nearby.preference()
        XCTAssertTrue(preference)
        let updatedPref = try await nearby.setPreference(false)
        XCTAssertFalse(updatedPref)
        let nearbyUsers = try await nearby.nearbyUsers(lat: 10.5, lon: 106.5)
        XCTAssertEqual(nearbyUsers.count, 0)
        try await nearby.leaveSession()

        // 17. Groups: FetchMyGroupsUseCase
        let fetchGroups = FetchMyGroupsUseCase(repository: groupsRepo)
        let groups = try await fetchGroups.execute()
        XCTAssertEqual(groups.count, 1)

        // 18. CreateGroupUseCase
        let createGroup = CreateGroupUseCase(repository: groupsRepo)
        let createdGroup = try await createGroup.execute(name: "Trip", description: nil)
        XCTAssertEqual(createdGroup.name, "Trip")

        // 19. FetchGroupMembersUseCase
        let fetchMembers = FetchGroupMembersUseCase(repository: groupsRepo)
        let members = try await fetchMembers.execute(groupId: dummyGroupId)
        XCTAssertEqual(members.count, 0)

        // 20. FetchGroupInviteCodeUseCase & GenerateGroupInviteCodeUseCase
        let fetchInvite = FetchGroupInviteCodeUseCase(repository: groupsRepo)
        let activeCode = try await fetchInvite.execute(groupId: dummyGroupId)
        XCTAssertNil(activeCode)

        let genInvite = GenerateGroupInviteCodeUseCase(repository: groupsRepo)
        let generatedCode = try await genInvite.execute(groupId: dummyGroupId)
        XCTAssertEqual(generatedCode.code, "INVITE123")

        // 21. InviteFriendsToGroupUseCase
        let inviteFriends = InviteFriendsToGroupUseCase(repository: groupsRepo)
        let inviteResult = try await inviteFriends.execute(groupId: dummyGroupId, userIds: [dummyUserId])
        XCTAssertEqual(inviteResult.invited.count, 1)

        // 22. JoinGroupUseCase
        let joinGroup = JoinGroupUseCase(repository: groupsRepo)
        let joinedByCode = try await joinGroup.execute(inviteCode: "CODE")
        XCTAssertEqual(joinedByCode.name, "Joined Group")
        let joinedByQr = try await joinGroup.executeFromQRCode("QR")
        XCTAssertEqual(joinedByQr.name, "Joined Group")

        // 23. GroupManagementUseCases
        let updateGroupUseCase = UpdateGroupUseCase(repository: groupsRepo)
        let updatedGroup = try await updateGroupUseCase.execute(groupId: dummyGroupId, name: "New Name", description: "Desc")
        XCTAssertEqual(updatedGroup.name, "New Name")

        let updateAvatarUseCase = UpdateGroupAvatarUseCase(repository: groupsRepo)
        let updatedAvatar = try await updateAvatarUseCase.execute(groupId: dummyGroupId, avatarURL: "https://example.com/new.png")
        XCTAssertEqual(updatedAvatar.name, "New Name")

        let deleteGroupUseCase = DeleteGroupUseCase(repository: groupsRepo)
        try await deleteGroupUseCase.execute(groupId: dummyGroupId)

        let leaveGroupUseCase = LeaveGroupUseCase(repository: groupsRepo)
        try await leaveGroupUseCase.execute(groupId: dummyGroupId)

        let transferOwnershipUseCase = TransferGroupOwnershipUseCase(repository: groupsRepo)
        let transferred = try await transferOwnershipUseCase.execute(groupId: dummyGroupId, newOwnerId: dummyUserId)
        XCTAssertEqual(transferred.name, "New Name")

        let approveMember = ApproveGroupMemberUseCase(repository: groupsRepo)
        try await approveMember.execute(groupId: dummyGroupId, memberRowId: dummyMemberId)

        let rejectMember = RejectGroupMemberUseCase(repository: groupsRepo)
        try await rejectMember.execute(groupId: dummyGroupId, memberRowId: dummyMemberId)

        let removeMember = RemoveGroupMemberUseCase(repository: groupsRepo)
        try await removeMember.execute(groupId: dummyGroupId, memberRowId: dummyMemberId)

        let generateGroupQr = GenerateGroupQrUseCase(repository: groupsRepo)
        let groupQr = try await generateGroupQr.execute(groupId: dummyGroupId, ttlSeconds: 60)
        XCTAssertEqual(groupQr.payload, "qr_payload")

        let revokeGroupQr = RevokeGroupQrUseCase(repository: groupsRepo)
        try await revokeGroupQr.execute(groupId: dummyGroupId, qrId: dummyGroupId)
    }
}

// MARK: - Mocks

private actor MockFriendsManagementRepository: FriendsManagementRepositoryProtocol {
    func fetchMyFriends() async throws -> [UserSummary] {
        [UserSummary(id: UUID(), username: "friend", displayName: "Friend", avatarURL: nil)]
    }

    func fetchMyFriendsPage(page: Int, size: Int) async throws -> FriendsPageResult {
        FriendsPageResult(
            friends: [UserSummary(id: UUID(), username: "friend", displayName: "Friend", avatarURL: nil)],
            page: page,
            hasMore: false
        )
    }

    func loadCachedFriends(userId: UUID) async -> [UserSummary]? { nil }
    func saveCachedFriends(_ friends: [UserSummary], userId: UUID) async {}
    func invalidateCachedFriends(userId: UUID) async {}

    func fetchUserProfile(userId: UUID) async throws -> PublicUserProfile {
        PublicUserProfile(
            user: UserSummary(id: userId, username: "hoan", displayName: "Hoan", avatarURL: nil),
            friendStatus: FriendRelationStatus.friends,
            stats: UserProfileStats(friendCount: 1, postCount: 1, groupCount: 1),
            isOnline: true,
            lastSeenAt: Date()
        )
    }

    func fetchFriendPaymentProfile(userId: UUID) async throws -> PaymentProfile {
        PaymentProfile(userId: userId, qrImageURL: nil, accountName: "HOAN", accountNumber: "1", bankName: "VCB", updatedAt: Date())
    }

    func searchUsers(query: String, page: Int, size: Int) async throws -> [UserSearchResult] {
        [UserSearchResult(user: UserSummary(id: UUID(), username: "hoan", displayName: "Hoan", avatarURL: nil), friendStatus: .none, distanceMeters: nil)]
    }

    func discoveryPreference() async throws -> Bool { true }
    func updateDiscoveryPreference(nearbyEnabled: Bool) async throws -> Bool { nearbyEnabled }
    func findNearbyUsers(lat: Double, lon: Double) async throws -> [UserSearchResult] { [] }
    func leaveNearbySession() async throws {}
    func searchUser(username: String) async throws -> UserSummary? { nil }

    func addFriend(username: String, message: String?) async throws -> UserSummary {
        UserSummary(id: UUID(), username: username, displayName: username, avatarURL: nil)
    }

    func fetchAllIncomingFriendRequests() async throws -> [IncomingFriendRequest] { [] }
    func fetchAllOutgoingFriendRequests() async throws -> [OutgoingFriendRequest] { [] }
    func fetchAllBlockedUsers() async throws -> [BlockedUser] { [] }
    func fetchIncomingFriendRequests(page: Int, size: Int) async throws -> [IncomingFriendRequest] { [] }
    func fetchOutgoingFriendRequests(page: Int, size: Int) async throws -> [OutgoingFriendRequest] { [] }
    func acceptFriendRequest(requestId: UUID) async throws {}
    func rejectFriendRequest(requestId: UUID) async throws {}
    func cancelFriendRequest(requestId: UUID) async throws {}
    func removeFriend(friendUserId: UUID) async throws {}

    func setFriendNickname(friendUserId: UUID, nickname: String?) async throws -> UserSummary {
        UserSummary(id: friendUserId, username: "u", displayName: nickname ?? "u", avatarURL: nil)
    }

    func fetchBlockedUsers(page: Int, size: Int) async throws -> [BlockedUser] { [] }
    func blockUser(userId: UUID) async throws {}
    func unblockUser(userId: UUID) async throws {}
    func addFriendFromQRCode(_ payload: String) async throws -> UserSummary {
        UserSummary(id: UUID(), username: "qr_user", displayName: "QR User", avatarURL: nil)
    }

    func generateMyQr() async throws -> PersonalQRCode {
        PersonalQRCode(payload: "splick://qr/hoan", version: 1, issuedAt: Date())
    }

    func revokeMyQr() async throws {}
}

private actor MockGroupsRepository: GroupsRepositoryProtocol {
    func fetchMyGroups() async throws -> [Group] {
        [Group(id: UUID(), name: "My Group", inviteCode: "C", description: nil, avatarURL: nil, members: [], createdBy: UUID())]
    }

    func fetchGroup(groupId: UUID) async throws -> Group {
        Group(id: groupId, name: "My Group", inviteCode: "C", description: nil, avatarURL: nil, members: [], createdBy: UUID())
    }

    func fetchGroupMembers(groupId: UUID, status: String?) async throws -> [GroupMemberItem] { [] }

    func createGroup(name: String, description: String?) async throws -> Group {
        Group(id: UUID(), name: name, inviteCode: "C", description: description, avatarURL: nil, members: [], createdBy: UUID())
    }

    func updateGroup(groupId: UUID, name: String, description: String?) async throws -> Group {
        Group(id: groupId, name: name, inviteCode: "C", description: description, avatarURL: nil, members: [], createdBy: UUID())
    }

    func updateGroupAvatar(groupId: UUID, avatarURL: String) async throws -> Group {
        Group(id: groupId, name: "New Name", inviteCode: "C", description: nil, avatarURL: URL(string: avatarURL), members: [], createdBy: UUID())
    }

    func deleteGroup(groupId: UUID) async throws {}
    func fetchActiveInviteCode(groupId: UUID) async throws -> GroupInviteCode? { nil }

    func generateInviteCode(groupId: UUID) async throws -> GroupInviteCode {
        GroupInviteCode(id: UUID(), code: "INVITE123", groupId: groupId, issuedAt: Date(), expiresAt: nil)
    }

    func revokeInviteCode(groupId: UUID, invitationId: UUID) async throws {}

    func generateGroupQr(groupId: UUID, ttlSeconds: Int?) async throws -> GroupServerQR {
        GroupServerQR(id: UUID(), payload: "qr_payload", groupId: groupId, issuedAt: Date(), expiresAt: Date().addingTimeInterval(300))
    }

    func revokeGroupQr(groupId: UUID, qrId: UUID) async throws {}

    func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult {
        InviteFriendsToGroupResult(invited: userIds, skipped: [])
    }

    func joinGroup(inviteCode: String) async throws -> Group {
        Group(id: UUID(), name: "Joined Group", inviteCode: inviteCode, description: nil, avatarURL: nil, members: [], createdBy: UUID())
    }

    func joinGroupFromQRCode(_ payload: String) async throws -> Group {
        Group(id: UUID(), name: "Joined Group", inviteCode: "QR", description: nil, avatarURL: nil, members: [], createdBy: UUID())
    }

    func approvePendingMember(groupId: UUID, memberRowId: UUID) async throws {}
    func rejectPendingMember(groupId: UUID, memberRowId: UUID) async throws {}
    func removeMember(groupId: UUID, memberRowId: UUID) async throws {}
    func leaveGroup(groupId: UUID) async throws {}

    func transferOwnership(groupId: UUID, newOwnerId: UUID) async throws -> Group {
        Group(id: groupId, name: "New Name", inviteCode: "C", description: nil, avatarURL: nil, members: [], createdBy: UUID())
    }
}

import Localization
import Storage

final class MockUserDefaultsService: UserDefaultsServiceProtocol {
    private var storage: [String: Any] = [:]
    func set<T: Codable>(_ value: T, for key: String) { storage[key] = value }
    func get<T: Codable>(for key: String) -> T? { storage[key] as? T }
    func setBool(_ value: Bool, for key: String) { storage[key] = value }
    func getBool(for key: String) -> Bool { (storage[key] as? Bool) ?? false }
    func remove(for key: String) { storage.removeValue(forKey: key) }
}

@MainActor
final class GroupDetailViewModelTests: XCTestCase {
    private var groupsRepo: MockGroupsRepository!
    private var languageService: LanguageService!
    private var ownerId: UUID!
    private var memberId: UUID!
    private var dummyGroup: Group!

    override func setUp() {
        super.setUp()
        groupsRepo = MockGroupsRepository()
        let defaults = MockUserDefaultsService()
        languageService = LanguageService(userDefaults: defaults)
        ownerId = UUID()
        memberId = UUID()
        dummyGroup = Group(
            id: UUID(),
            name: "Test Group",
            inviteCode: "TG123",
            description: "A test group",
            avatarURL: nil,
            members: [],
            memberCount: 2,
            createdBy: ownerId,
            createdAt: Date()
        )
    }

    func testGroupDetailViewModelFlow() async {
        let memberItem1 = GroupMemberItem(
            id: UUID(),
            userId: ownerId,
            username: "owner",
            displayName: "Owner User",
            avatarURL: nil,
            role: "OWNER",
            status: "ACTIVE"
        )
        let memberItem2 = GroupMemberItem(
            id: UUID(),
            userId: memberId,
            username: "member",
            displayName: "Member User",
            avatarURL: nil,
            role: "MEMBER",
            status: "ACTIVE"
        )

        let fetchMembers = FetchGroupMembersUseCase(repository: groupsRepo)
        let fetchInvite = FetchGroupInviteCodeUseCase(repository: groupsRepo)
        let generateInvite = GenerateGroupInviteCodeUseCase(repository: groupsRepo)
        let fetchGroup = FetchGroupUseCase(repository: groupsRepo)
        let approveMember = ApproveGroupMemberUseCase(repository: groupsRepo)
        let rejectMember = RejectGroupMemberUseCase(repository: groupsRepo)
        let removeMember = RemoveGroupMemberUseCase(repository: groupsRepo)
        let leaveGroup = LeaveGroupUseCase(repository: groupsRepo)
        let deleteGroup = DeleteGroupUseCase(repository: groupsRepo)

        let vm = GroupDetailViewModel(
            group: dummyGroup,
            fetchGroupMembersUseCase: fetchMembers,
            fetchInviteCodeUseCase: fetchInvite,
            generateInviteCodeUseCase: generateInvite,
            fetchGroupUseCase: fetchGroup,
            approveMemberUseCase: approveMember,
            rejectMemberUseCase: rejectMember,
            removeMemberUseCase: removeMember,
            leaveGroupUseCase: leaveGroup,
            deleteGroupUseCase: deleteGroup,
            languageService: languageService
        )

        XCTAssertEqual(vm.group.name, "Test Group")
        XCTAssertEqual(vm.displayedInviteCode, "TG123")
        XCTAssertTrue(vm.isOwner(currentUserId: ownerId))
        XCTAssertFalse(vm.isOwner(currentUserId: memberId))

        // Check member sorting
        let sorted = vm.sortedMembers(currentUserId: ownerId)
        XCTAssertTrue(sorted.isEmpty)

        // Test approve & reject as owner
        await vm.approve(memberItem2, currentUserId: ownerId)
        await vm.reject(memberItem2, currentUserId: ownerId)

        // Test remove owner should fail
        await vm.remove(memberItem1, currentUserId: ownerId)
        XCTAssertNotNil(vm.actionError)

        // Test remove regular member
        await vm.remove(memberItem2, currentUserId: ownerId)

        // Test owner leave triggers transfer
        let ownerLeave = await vm.leave(currentUserId: ownerId)
        XCTAssertFalse(ownerLeave)
        XCTAssertTrue(vm.showTransferBeforeLeave)

        // Test non-owner leave succeeds
        let memberLeave = await vm.leave(currentUserId: memberId)
        XCTAssertTrue(memberLeave)

        // Test delete group
        let deleteResult = await vm.deleteGroup(currentUserId: ownerId)
        XCTAssertTrue(deleteResult)
    }
}

final class MockNearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol, @unchecked Sendable {
    var isEnabled = false
    func preference() async throws -> Bool { isEnabled }
    func setPreference(_ enabled: Bool) async throws -> Bool {
        isEnabled = enabled
        return enabled
    }
    func nearbyUsers(lat: Double, lon: Double) async throws -> [UserSearchResult] { [] }
    func leaveSession() async throws {}
}

@MainActor
final class FriendsRootViewModelTests: XCTestCase {
    private var friendsRepo: MockFriendsManagementRepository!
    private var groupsRepo: MockGroupsRepository!
    private var languageService: LanguageService!

    override func setUp() {
        super.setUp()
        friendsRepo = MockFriendsManagementRepository()
        groupsRepo = MockGroupsRepository()
        let defaults = MockUserDefaultsService()
        languageService = LanguageService(userDefaults: defaults)
    }

    func testFriendsRootViewModelFlow() async {
        let fetchFriends = FetchMyFriendsUseCase(repository: friendsRepo)
        let fetchGroups = FetchMyGroupsUseCase(repository: groupsRepo)
        let searchUsers = SearchUsersUseCase(repository: friendsRepo)
        let addFriend = AddFriendUseCase(repository: friendsRepo)
        let acceptRequest = AcceptFriendRequestUseCase(repository: friendsRepo)
        let fetchIncoming = FetchIncomingFriendRequestsUseCase(repository: friendsRepo)
        let fetchOutgoing = FetchOutgoingFriendRequestsUseCase(repository: friendsRepo)
        let cancelRequest = CancelFriendRequestUseCase(repository: friendsRepo)
        let nearby = MockNearbyDiscoveryUseCase()

        let vm = FriendsRootViewModel(
            fetchMyFriendsUseCase: fetchFriends,
            fetchMyGroupsUseCase: fetchGroups,
            searchUsersUseCase: searchUsers,
            addFriendUseCase: addFriend,
            acceptFriendRequestUseCase: acceptRequest,
            fetchIncomingFriendRequestsUseCase: fetchIncoming,
            fetchOutgoingFriendRequestsUseCase: fetchOutgoing,
            cancelFriendRequestUseCase: cancelRequest,
            nearbyDiscoveryUseCase: nearby,
            languageService: languageService
        )

        XCTAssertFalse(vm.isSearching)
        XCTAssertEqual(vm.friends.count, 0)
        XCTAssertEqual(vm.groups.count, 0)

        // Load friends
        let dummyUserId = UUID()
        await vm.load(userId: dummyUserId)
        XCTAssertEqual(vm.friends.count, 1)

        // Visibility & Polling
        vm.onFriendsVisible()
        vm.onFriendsHidden()

        // Nearby setting
        vm.setNearbyEnabled(true)
        vm.stopRadarSession()

        // Search flow
        await vm.refreshSearch(query: "hoan")
        XCTAssertEqual(vm.searchResults.count, 1)

        // Snapshot
        let snapshot = vm.peopleYouMayKnowSnapshot(blocked: [])
        XCTAssertEqual(snapshot.friends.count, 1)
    }
}
