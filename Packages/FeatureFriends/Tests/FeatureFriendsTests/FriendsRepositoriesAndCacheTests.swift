import XCTest
import SplickDomain
import Common
import Networking
import Storage
@testable import FeatureFriends

final class FriendsRepositoriesAndCacheTests: XCTestCase {

    private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
        var responseMap: [String: Any] = [:]
        var lastEndpoint: (any APIEndpoint)?
        var shouldThrow: Error?

        func request<T: Decodable>(_ endpoint: any APIEndpoint) async throws -> T {
            lastEndpoint = endpoint
            if let shouldThrow {
                throw shouldThrow
            }
            let key = String(describing: T.self)
            if let res = responseMap[key] as? T {
                return res
            }
            throw NetworkError.unknown("Unknown error")
        }

        func request(_ endpoint: any APIEndpoint) async throws {
            lastEndpoint = endpoint
            if let shouldThrow {
                throw shouldThrow
            }
        }

        func upload<T: Decodable>(_ endpoint: any APIEndpoint, data: Data, mimeType: String) async throws -> T {
            try await request(endpoint)
        }
    }

    func testFriendsCachePayloadAndDisk() async {
        let user = UserSummary(id: UUID(), username: "cuser", displayName: "CUser", avatarURL: nil)
        let payload = FriendsCachePayload(friends: [user])
        XCTAssertEqual(payload.friends.count, 1)

        let repo = FriendsManagementRepository(apiClient: MockAPIClient())
        let userId = UUID()
        await repo.saveCachedFriends([user], userId: userId)
        let cached = await repo.loadCachedFriends(userId: userId)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 1)
        await repo.invalidateCachedFriends(userId: userId)
        let invalidated = await repo.loadCachedFriends(userId: userId)
        XCTAssertNil(invalidated)
    }

    func testFriendsManagementRepository_APIHits() async throws {
        let client = MockAPIClient()
        let repo = FriendsManagementRepository(apiClient: client)
        let userId = UUID()
        let requestId = UUID()

        // 1. fetchUserProfile
        let userProfileDTO = UserProfileResponseDTO(
            userId: userId,
            username: "u1",
            displayName: "U1",
            avatarUrl: nil,
            nickname: nil,
            subtitle: nil,
            friendStatus: "NONE",
            stats: UserProfileStatsResponseDTO(friendCount: 0, postCount: 0, groupCount: 0),
            online: false,
            lastSeenAt: nil
        )
        client.responseMap[String(describing: UserProfileResponseDTO.self)] = userProfileDTO
        let profile = try await repo.fetchUserProfile(userId: userId)
        XCTAssertEqual(profile.user.username, "u1")

        // 2. fetchFriendPaymentProfile
        let paymentDTO = PaymentProfileResponseDTO(
            userId: userId,
            qrImageUrl: nil,
            accountName: "ACC",
            accountNumber: "123",
            bankName: "BANK",
            updatedAt: Date()
        )
        client.responseMap[String(describing: PaymentProfileResponseDTO.self)] = paymentDTO
        let pay = try await repo.fetchFriendPaymentProfile(userId: userId)
        XCTAssertEqual(pay.accountName, "ACC")

        // 3. searchUsers empty query
        let pageFriendDTO = SocialPageFriendResponseDTO(
            content: [],
            page: SocialPageMetaDTO(page: 0, size: 20, totalElements: 0, totalPages: 1)
        )
        client.responseMap[String(describing: SocialPageFriendResponseDTO.self)] = pageFriendDTO
        let searchEmpty = try await repo.searchUsers(query: "", page: 0, size: 20)
        XCTAssertTrue(searchEmpty.isEmpty)

        // 4. searchUsers with query
        let searchDTO = SocialPageUserSearchResponseDTO(
            content: [UserSearchResponseDTO(userId: userId, username: "u1", displayName: "U1", avatarUrl: nil, friendStatus: "NONE", distanceMeters: nil)],
            page: SocialPageMetaDTO(page: 0, size: 20, totalElements: 1, totalPages: 1)
        )
        client.responseMap[String(describing: SocialPageUserSearchResponseDTO.self)] = searchDTO
        let searchResults = try await repo.searchUsers(query: "u1", page: 0, size: 20)
        XCTAssertEqual(searchResults.count, 1)

        // 5. searchUser single username
        let singleUser = try await repo.searchUser(username: "u1")
        XCTAssertEqual(singleUser?.username, "u1")
        let emptySingleUser = try await repo.searchUser(username: "")
        XCTAssertNil(emptySingleUser)

        // 6. discoveryPreference & updateDiscoveryPreference
        let prefDTO = DiscoveryPreferenceResponseDTO(nearbyEnabled: true)
        client.responseMap[String(describing: DiscoveryPreferenceResponseDTO.self)] = prefDTO
        let isEnabled = try await repo.discoveryPreference()
        XCTAssertTrue(isEnabled)
        let updatedPref = try await repo.updateDiscoveryPreference(nearbyEnabled: false)
        XCTAssertTrue(updatedPref)

        // 7. findNearbyUsers
        client.responseMap[String(describing: SocialPageUserSearchResponseDTO.self)] = searchDTO
        let nearby = try await repo.findNearbyUsers(lat: 1.0, lon: 2.0)
        XCTAssertEqual(nearby.count, 1)

        // 8. leaveNearbySession
        try await repo.leaveNearbySession()

        // 9. addFriend
        let reqDTO = FriendRequestResponseDTO(
            id: requestId,
            requesterId: UUID(),
            addresseeId: userId,
            status: "PENDING",
            message: "Hi",
            createdAt: Date(),
            expiresAt: Date(),
            addresseeUsername: "u1",
            addresseeDisplayName: "U1"
        )
        client.responseMap[String(describing: FriendRequestResponseDTO.self)] = reqDTO
        let added = try await repo.addFriend(username: "u1", message: "Hi")
        XCTAssertEqual(added.username, "u1")

        do {
            _ = try await repo.addFriend(username: "   ", message: nil)
            XCTFail("Should throw on empty username")
        } catch {}

        // 10. addFriendFromQRCode
        let qrUser = try await repo.addFriendFromQRCode("splick://friend/u1")
        XCTAssertEqual(qrUser.username, "u1")

        let qrServerUser = try await repo.addFriendFromQRCode("splick://friend/u1")
        XCTAssertEqual(qrServerUser.username, "u1")

        do {
            _ = try await repo.addFriendFromQRCode("invalid_qr")
            XCTFail("Should throw on invalid QR")
        } catch {}

        // 11. fetchIncoming, fetchOutgoing, fetchBlocked
        let incomingDTO = SocialPageIncomingFriendRequestResponseDTO(
            content: [],
            page: SocialPageMetaDTO(page: 0, size: 20, totalElements: 0, totalPages: 1)
        )
        client.responseMap[String(describing: SocialPageIncomingFriendRequestResponseDTO.self)] = incomingDTO
        let incoming = try await repo.fetchIncomingFriendRequests(page: 0, size: 20)
        XCTAssertTrue(incoming.isEmpty)
        let allIncoming = try await repo.fetchAllIncomingFriendRequests()
        XCTAssertTrue(allIncoming.isEmpty)

        let outgoingDTO = SocialPageFriendRequestResponseDTO(
            content: [],
            page: SocialPageMetaDTO(page: 0, size: 20, totalElements: 0, totalPages: 1)
        )
        client.responseMap[String(describing: SocialPageFriendRequestResponseDTO.self)] = outgoingDTO
        let outgoing = try await repo.fetchOutgoingFriendRequests(page: 0, size: 20)
        XCTAssertTrue(outgoing.isEmpty)
        let allOutgoing = try await repo.fetchAllOutgoingFriendRequests()
        XCTAssertTrue(allOutgoing.isEmpty)

        let blockedDTO = SocialPageBlockedUserResponseDTO(
            content: [],
            page: SocialPageMetaDTO(page: 0, size: 20, totalElements: 0, totalPages: 1)
        )
        client.responseMap[String(describing: SocialPageBlockedUserResponseDTO.self)] = blockedDTO
        let blocked = try await repo.fetchBlockedUsers(page: 0, size: 20)
        XCTAssertTrue(blocked.isEmpty)
        let allBlocked = try await repo.fetchAllBlockedUsers()
        XCTAssertTrue(allBlocked.isEmpty)

        // 12. Actions
        try await repo.acceptFriendRequest(requestId: requestId)
        try await repo.rejectFriendRequest(requestId: requestId)
        try await repo.cancelFriendRequest(requestId: requestId)
        try await repo.removeFriend(friendUserId: userId)
        try await repo.blockUser(userId: userId)
        try await repo.unblockUser(userId: userId)

        // 13. setFriendNickname
        let friendDTO = FriendResponseDTO(
            friendId: userId,
            username: "u1",
            displayName: "Nick",
            avatarUrl: nil,
            nickname: "Nick",
            friendsSince: Date(),
            online: true,
            lastSeenAt: Date()
        )
        client.responseMap[String(describing: FriendResponseDTO.self)] = friendDTO
        let nickResult = try await repo.setFriendNickname(friendUserId: userId, nickname: "Nick")
        XCTAssertEqual(nickResult.displayName, "Nick")

        // 14. generateMyQr & revokeMyQr
        let myQrDTO = MyQRResponseDTO(payload: "payload", version: 1, issuedAt: Date())
        client.responseMap[String(describing: MyQRResponseDTO.self)] = myQrDTO
        let myQr = try await repo.generateMyQr()
        XCTAssertEqual(myQr.payload, "payload")
        try await repo.revokeMyQr()
    }

    func testGroupsRepository_APIHits() async throws {
        let client = MockAPIClient()
        let repo = GroupsRepository(apiClient: client)
        let groupId = UUID()
        let memberRowId = UUID()

        let groupDTO = GroupResponseDTO(
            id: groupId,
            name: "Test Group",
            description: "Desc",
            avatarUrl: nil,
            ownerId: UUID(),
            createdAt: Date()
        )
        client.responseMap[String(describing: GroupResponseDTO.self)] = groupDTO

        // 1. fetchMyGroups & fetchGroup
        let groupSummaryDTO = GroupSummaryResponseDTO(
            id: groupId,
            name: "Test Group",
            avatarUrl: nil,
            ownerId: UUID(),
            createdAt: Date(),
            memberCount: 1
        )
        let pageGroupDTO = SocialPageGroupSummaryResponseDTO(
            content: [groupSummaryDTO],
            page: SocialPageMetaDTO(page: 0, size: 20, totalElements: 1, totalPages: 1)
        )
        client.responseMap[String(describing: SocialPageGroupSummaryResponseDTO.self)] = pageGroupDTO
        let myGroups = try await repo.fetchMyGroups()
        XCTAssertEqual(myGroups.count, 1)

        let fetchedGroup = try await repo.fetchGroup(groupId: groupId)
        XCTAssertEqual(fetchedGroup.name, "Test Group")

        // 2. fetchGroupMembers
        let pageMemberDTO = SocialPageMemberResponseDTO(
            content: [],
            page: SocialPageMetaDTO(page: 0, size: 20, totalElements: 0, totalPages: 1)
        )
        client.responseMap[String(describing: SocialPageMemberResponseDTO.self)] = pageMemberDTO
        let members = try await repo.fetchGroupMembers(groupId: groupId)
        XCTAssertTrue(members.isEmpty)

        // 3. createGroup
        let created = try await repo.createGroup(name: "New Group", description: "Desc")
        XCTAssertEqual(created.name, "Test Group")

        do {
            _ = try await repo.createGroup(name: "   ", description: nil)
            XCTFail("Should throw on empty group name")
        } catch {}

        // 4. updateGroup & updateGroupAvatar
        let updated = try await repo.updateGroup(groupId: groupId, name: "Name", description: "Desc")
        XCTAssertEqual(updated.name, "Test Group")
        let updatedAvatar = try await repo.updateGroupAvatar(groupId: groupId, avatarURL: "https://avatar.png")
        XCTAssertEqual(updatedAvatar.name, "Test Group")

        // 5. deleteGroup
        try await repo.deleteGroup(groupId: groupId)

        // 6. fetchActiveInviteCode & generateInviteCode & revokeInviteCode
        let inviteDTO = InviteCodeResponseDTO(
            id: UUID(),
            code: "INVITE123",
            groupId: groupId,
            issuedAt: Date(),
            expiresAt: nil,
            maxUses: nil,
            usedCount: 0
        )
        client.responseMap[String(describing: InviteCodeResponseDTO.self)] = inviteDTO
        let activeCode = try await repo.fetchActiveInviteCode(groupId: groupId)
        XCTAssertEqual(activeCode?.code, "INVITE123")

        let genCode = try await repo.generateInviteCode(groupId: groupId)
        XCTAssertEqual(genCode.code, "INVITE123")
        try await repo.revokeInviteCode(groupId: groupId, invitationId: UUID())

        client.shouldThrow = NetworkError.notFound
        let nilCode = try await repo.fetchActiveInviteCode(groupId: groupId)
        XCTAssertNil(nilCode)
        client.shouldThrow = nil

        // 7. generateGroupQr & revokeGroupQr
        let groupQrDTO = GroupQRResponseDTO(
            id: UUID(),
            payload: "group_qr",
            groupId: groupId,
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(300)
        )
        client.responseMap[String(describing: GroupQRResponseDTO.self)] = groupQrDTO
        let gQr = try await repo.generateGroupQr(groupId: groupId, ttlSeconds: 60)
        XCTAssertEqual(gQr.payload, "group_qr")
        try await repo.revokeGroupQr(groupId: groupId, qrId: UUID())

        // 8. inviteFriends
        let inviteResDTO = InviteFriendsResponseDTO(invited: [UUID()], skipped: [])
        client.responseMap[String(describing: InviteFriendsResponseDTO.self)] = inviteResDTO
        let inviteRes = try await repo.inviteFriends(groupId: groupId, userIds: [UUID()])
        XCTAssertEqual(inviteRes.invited.count, 1)

        do {
            _ = try await repo.inviteFriends(groupId: groupId, userIds: [])
            XCTFail("Should throw on empty invite list")
        } catch {}

        // 9. joinGroup & joinGroupFromQRCode
        let joinDTO = JoinGroupResponseDTO(groupId: groupId, membershipId: UUID(), status: "ACTIVE")
        client.responseMap[String(describing: JoinGroupResponseDTO.self)] = joinDTO
        let joinedGroup = try await repo.joinGroup(inviteCode: "GROUP12345")
        XCTAssertEqual(joinedGroup.id, groupId)

        let joinedQrGroup = try await repo.joinGroupFromQRCode("splick://group/GROUP12345")
        XCTAssertEqual(joinedQrGroup.id, groupId)

        let joinedServerQrGroup = try await repo.joinGroupFromQRCode("https://splick.app/group/join?payload=p123")
        XCTAssertEqual(joinedServerQrGroup.id, groupId)

        let joinedRawGroup = try await repo.joinGroupFromQRCode("raw_qr_payload")
        XCTAssertEqual(joinedRawGroup.id, groupId)

        // 10. Member management & leave & transferOwnership
        let memberDTO = MemberResponseDTO(
            id: memberRowId,
            userId: UUID(),
            username: "m1",
            displayName: "M1",
            avatarUrl: nil,
            role: "MEMBER",
            status: "ACTIVE"
        )
        client.responseMap[String(describing: MemberResponseDTO.self)] = memberDTO
        try await repo.approvePendingMember(groupId: groupId, memberRowId: memberRowId)
        try await repo.rejectPendingMember(groupId: groupId, memberRowId: memberRowId)
        try await repo.removeMember(groupId: groupId, memberRowId: memberRowId)
        try await repo.leaveGroup(groupId: groupId)
        let transferred = try await repo.transferOwnership(groupId: groupId, newOwnerId: UUID())
        XCTAssertEqual(transferred.id, groupId)
    }

    func testFriendsErrorDescriptions() {
        let errs: [FriendsError] = [
            .notImplemented, .invalidGroupName, .invalidInviteSelection, .invalidUsername,
            .userNotFound, .alreadyFriends, .invalidQRCode, .groupNotFound, .alreadyInGroup
        ]
        for err in errs {
            XCTAssertFalse(err.errorDescription!.isEmpty)
        }
    }
}
