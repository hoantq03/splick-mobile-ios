import XCTest
import SplickDomain
import Common
import Storage
import Localization
@testable import FeatureFriends

@MainActor
final class FriendsDomainModelsAndUtilitiesTests: XCTestCase {

    private final class MockStorage: UserDefaultsServiceProtocol {
        private var storage: [String: Any] = [:]
        func set<T: Codable>(_ value: T, for key: String) { storage[key] = value }
        func get<T: Codable>(for key: String) -> T? { storage[key] as? T }
        func setBool(_ value: Bool, for key: String) { storage[key] = value }
        func getBool(for key: String) -> Bool { (storage[key] as? Bool) ?? false }
        func remove(for key: String) { storage.removeValue(forKey: key) }
    }

    private actor MockGroupsRepo: GroupsRepositoryProtocol {
        func fetchMyGroups() async throws -> [Group] {
            [Group(id: UUID(), name: "G1", inviteCode: "C1", description: nil, avatarURL: nil, members: [], createdBy: UUID())]
        }
        func fetchGroup(groupId: UUID) async throws -> Group {
            Group(id: groupId, name: "G1", inviteCode: "C1", description: nil, avatarURL: nil, members: [], createdBy: UUID())
        }
        func fetchGroupMembers(groupId: UUID, status: String?) async throws -> [GroupMemberItem] {
            [GroupMemberItem(id: UUID(), userId: UUID(), username: "guser", displayName: "GUser", avatarURL: nil, role: "MEMBER", status: "ACTIVE")]
        }
        func createGroup(name: String, description: String?) async throws -> Group {
            Group(id: UUID(), name: name, inviteCode: "C", description: description, avatarURL: nil, members: [], createdBy: UUID())
        }
        func updateGroup(groupId: UUID, name: String, description: String?) async throws -> Group {
            Group(id: groupId, name: name, inviteCode: "C", description: description, avatarURL: nil, members: [], createdBy: UUID())
        }
        func updateGroupAvatar(groupId: UUID, avatarURL: String) async throws -> Group {
            Group(id: groupId, name: "G", inviteCode: "C", description: nil, avatarURL: URL(string: avatarURL), members: [], createdBy: UUID())
        }
        func deleteGroup(groupId: UUID) async throws {}
        func fetchActiveInviteCode(groupId: UUID) async throws -> GroupInviteCode? { nil }
        func generateInviteCode(groupId: UUID) async throws -> GroupInviteCode {
            GroupInviteCode(id: UUID(), code: "C", groupId: groupId, issuedAt: Date(), expiresAt: nil)
        }
        func revokeInviteCode(groupId: UUID, invitationId: UUID) async throws {}
        func generateGroupQr(groupId: UUID, ttlSeconds: Int?) async throws -> GroupServerQR {
            GroupServerQR(id: UUID(), payload: "p", groupId: groupId, issuedAt: Date(), expiresAt: Date())
        }
        func revokeGroupQr(groupId: UUID, qrId: UUID) async throws {}
        func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult {
            InviteFriendsToGroupResult(invited: userIds, skipped: [])
        }
        func joinGroup(inviteCode: String) async throws -> Group {
            Group(id: UUID(), name: "Joined", inviteCode: inviteCode, description: nil, avatarURL: nil, members: [], createdBy: UUID())
        }
        func joinGroupFromQRCode(_ payload: String) async throws -> Group {
            Group(id: UUID(), name: "Joined", inviteCode: "QR", description: nil, avatarURL: nil, members: [], createdBy: UUID())
        }
        func approvePendingMember(groupId: UUID, memberRowId: UUID) async throws {}
        func rejectPendingMember(groupId: UUID, memberRowId: UUID) async throws {}
        func removeMember(groupId: UUID, memberRowId: UUID) async throws {}
        func leaveGroup(groupId: UUID) async throws {}
        func transferOwnership(groupId: UUID, newOwnerId: UUID) async throws -> Group {
            Group(id: groupId, name: "T", inviteCode: "C", description: nil, avatarURL: nil, members: [], createdBy: UUID())
        }
    }

    private actor MockFriendsRepo: FriendsManagementRepositoryProtocol {
        func fetchMyFriends() async throws -> [UserSummary] { [] }
        func fetchMyFriendsPage(page: Int, size: Int) async throws -> FriendsPageResult {
            FriendsPageResult(friends: [], page: page, hasMore: false)
        }
        func loadCachedFriends(userId: UUID) async -> [UserSummary]? { nil }
        func saveCachedFriends(_ friends: [UserSummary], userId: UUID) async {}
        func invalidateCachedFriends(userId: UUID) async {}
        func fetchUserProfile(userId: UUID) async throws -> PublicUserProfile {
            PublicUserProfile(user: UserSummary(id: userId, username: "u", displayName: "U", avatarURL: nil), friendStatus: .none, stats: UserProfileStats(friendCount: 0, postCount: 0, groupCount: 0))
        }
        func fetchFriendPaymentProfile(userId: UUID) async throws -> PaymentProfile {
            PaymentProfile(userId: userId, qrImageURL: nil, accountName: "A", accountNumber: "1", bankName: "B", updatedAt: Date())
        }
        func searchUsers(query: String, page: Int, size: Int) async throws -> [UserSearchResult] { [] }
        func discoveryPreference() async throws -> Bool { true }
        func updateDiscoveryPreference(nearbyEnabled: Bool) async throws -> Bool { nearbyEnabled }
        func findNearbyUsers(lat: Double, lon: Double) async throws -> [UserSearchResult] { [] }
        func leaveNearbySession() async throws {}
        func searchUser(username: String) async throws -> UserSummary? { nil }
        func addFriend(username: String, message: String?) async throws -> UserSummary {
            UserSummary(id: UUID(), username: username, displayName: username, avatarURL: nil)
        }
        func fetchIncomingFriendRequests(page: Int, size: Int) async throws -> [IncomingFriendRequest] { [] }
        func fetchOutgoingFriendRequests(page: Int, size: Int) async throws -> [OutgoingFriendRequest] { [] }
        func fetchBlockedUsers(page: Int, size: Int) async throws -> [BlockedUser] { [] }
        func fetchAllIncomingFriendRequests() async throws -> [IncomingFriendRequest] { [] }
        func fetchAllOutgoingFriendRequests() async throws -> [OutgoingFriendRequest] { [] }
        func fetchAllBlockedUsers() async throws -> [BlockedUser] { [] }
        func acceptFriendRequest(requestId: UUID) async throws {}
        func rejectFriendRequest(requestId: UUID) async throws {}
        func cancelFriendRequest(requestId: UUID) async throws {}
        func removeFriend(friendUserId: UUID) async throws {}
        func setFriendNickname(friendUserId: UUID, nickname: String?) async throws -> UserSummary {
            UserSummary(id: friendUserId, username: "u", displayName: nickname ?? "u", avatarURL: nil)
        }
        func blockUser(userId: UUID) async throws {}
        func unblockUser(userId: UUID) async throws {}
        func addFriendFromQRCode(_ raw: String) async throws -> UserSummary {
            UserSummary(id: UUID(), username: "qr", displayName: "QR", avatarURL: nil)
        }
        func generateMyQr() async throws -> PersonalQRCode {
            PersonalQRCode(payload: "payload", version: 1, issuedAt: Date())
        }
        func revokeMyQr() async throws {}
    }

    func testSplickQRParser_AllBranches() {
        XCTAssertNil(SplickQRParser.parse(""))
        XCTAssertNil(SplickQRParser.parse("   "))

        // Scheme splick://
        XCTAssertEqual(SplickQRParser.parse("splick://friend/alice"), .addFriend(username: "alice"))
        XCTAssertEqual(SplickQRParser.parse("splick://group/GROUP123"), .joinGroup(inviteCode: "GROUP123"))
        let splitId = UUID()
        XCTAssertEqual(SplickQRParser.parse("splick://bill/TOKEN123?split=\(splitId.uuidString)"), .claimBill(token: "TOKEN123", splitId: splitId))

        // Web HTTP/HTTPS URLs
        XCTAssertEqual(SplickQRParser.parse("https://splick.app/friend/bob"), .addFriend(username: "bob"))
        XCTAssertEqual(SplickQRParser.parse("https://splick.app/group/GRP456"), .joinGroup(inviteCode: "GRP456"))
        XCTAssertEqual(SplickQRParser.parse("https://splick.app/group/join?payload=server_payload"), .joinGroupByServerPayload("server_payload"))
        XCTAssertEqual(SplickQRParser.parse("https://splick.app/b/BILL123?split=\(splitId.uuidString)"), .claimBill(token: "BILL123", splitId: splitId))
        XCTAssertEqual(SplickQRParser.parse("https://splick.app/b/t/TOKEN123"), .claimBill(token: "TOKEN123", splitId: nil))
        XCTAssertEqual(SplickQRParser.parse("https://splick.app/charlie"), .addFriend(username: "charlie"))

        // Prefix fallbacks
        XCTAssertEqual(SplickQRParser.parse("friend:dave"), .addFriend(username: "dave"))
        XCTAssertEqual(SplickQRParser.parse("group:GRP789"), .joinGroup(inviteCode: "GRP789"))
        XCTAssertNil(SplickQRParser.parse("friend:"))

        // Generators
        XCTAssertEqual(SplickQRParser.friendPayload(username: "alice"), "splick://friend/alice")
        XCTAssertEqual(SplickQRParser.groupPayload(inviteCode: "C123"), "splick://group/C123")
    }

    func testFetchPeopleYouMayKnowUseCase() async throws {
        let groupsRepo = MockGroupsRepo()
        let friendsRepo = MockFriendsRepo()

        let fetchGroups = FetchMyGroupsUseCase(repository: groupsRepo)
        let fetchMembers = FetchGroupMembersUseCase(repository: groupsRepo)
        let fetchFriends = FetchMyFriendsUseCase(repository: friendsRepo)
        let fetchIncoming = FetchIncomingFriendRequestsUseCase(repository: friendsRepo)
        let fetchOutgoing = FetchOutgoingFriendRequestsUseCase(repository: friendsRepo)
        let fetchBlocked = FetchBlockedUsersUseCase(repository: friendsRepo)

        let useCase = FetchPeopleYouMayKnowUseCase(
            fetchMyGroupsUseCase: fetchGroups,
            fetchGroupMembersUseCase: fetchMembers,
            fetchMyFriendsUseCase: fetchFriends,
            fetchIncomingFriendRequestsUseCase: fetchIncoming,
            fetchOutgoingFriendRequestsUseCase: fetchOutgoing,
            fetchBlockedUsersUseCase: fetchBlocked
        )

        let currentUserId = UUID()
        let suggestions = try await useCase.execute(currentUserId: currentUserId, snapshot: nil)
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.user.username, "guser")
        XCTAssertEqual(suggestions.first?.sharedGroupName, "G1")
    }

    func testGroupMemberItemAndBlockedUser() {
        let memberActive = GroupMemberItem(id: UUID(), userId: UUID(), username: "u", displayName: "U", avatarURL: nil, role: "OWNER", status: "ACTIVE")
        XCTAssertFalse(memberActive.isPending)
        XCTAssertTrue(memberActive.isOwner)

        let memberPending = GroupMemberItem(id: UUID(), userId: UUID(), username: "u", displayName: "U", avatarURL: nil, role: "MEMBER", status: "PENDING_APPROVAL")
        XCTAssertTrue(memberPending.isPending)
        XCTAssertFalse(memberPending.isOwner)

        let blocked = BlockedUser(user: UserSummary(id: UUID(), username: "b", displayName: "B", avatarURL: nil), blockedAt: Date())
        XCTAssertEqual(blocked.id, blocked.user.id)
    }

    func testIncomingOutgoingAndBlockedViewModels() async {
        let friendsRepo = MockFriendsRepo()
        let langService = LanguageService(userDefaults: MockStorage())

        // Incoming
        let fetchIncoming = FetchIncomingFriendRequestsUseCase(repository: friendsRepo)
        let acceptReq = AcceptFriendRequestUseCase(repository: friendsRepo)
        let rejectReq = RejectFriendRequestUseCase(repository: friendsRepo)
        let incomingVM = IncomingFriendRequestsViewModel(
            fetchIncomingUseCase: fetchIncoming,
            acceptUseCase: acceptReq,
            rejectUseCase: rejectReq,
            onRelationshipChanged: { _, _ in }
        )
        await incomingVM.load()
        XCTAssertTrue(incomingVM.requests.isEmpty)

        // Outgoing
        let fetchOutgoing = FetchOutgoingFriendRequestsUseCase(repository: friendsRepo)
        let cancelReq = CancelFriendRequestUseCase(repository: friendsRepo)
        let outgoingVM = OutgoingFriendRequestsViewModel(
            fetchOutgoingUseCase: fetchOutgoing,
            cancelUseCase: cancelReq,
            onRelationshipChanged: { _, _ in }
        )
        await outgoingVM.load()
        XCTAssertTrue(outgoingVM.requests.isEmpty)

        // Blocked
        let fetchBlocked = FetchBlockedUsersUseCase(repository: friendsRepo)
        let unblockUser = UnblockUserUseCase(repository: friendsRepo)
        let blockedVM = BlockedUsersViewModel(
            fetchBlockedUsersUseCase: fetchBlocked,
            unblockUserUseCase: unblockUser,
            onRelationshipChanged: { _, _ in }
        )
        await blockedVM.load()
        XCTAssertTrue(blockedVM.blockedUsers.isEmpty)

        // MyQRViewModel
        let genMyQr = GenerateMyQrUseCase(repository: friendsRepo)
        let myQrVM = MyQRViewModel(generateMyQrUseCase: genMyQr)
        await myQrVM.load()
        XCTAssertNotNil(myQrVM.payload)

        // PeopleYouMayKnowViewModel
        let groupsRepo = MockGroupsRepo()
        let pymkUseCase = FetchPeopleYouMayKnowUseCase(
            fetchMyGroupsUseCase: FetchMyGroupsUseCase(repository: groupsRepo),
            fetchGroupMembersUseCase: FetchGroupMembersUseCase(repository: groupsRepo),
            fetchMyFriendsUseCase: FetchMyFriendsUseCase(repository: friendsRepo),
            fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCase(repository: friendsRepo),
            fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCase(repository: friendsRepo),
            fetchBlockedUsersUseCase: FetchBlockedUsersUseCase(repository: friendsRepo)
        )
        let addFriendUseCase = AddFriendUseCase(repository: friendsRepo)
        let pymkVM = PeopleYouMayKnowViewModel(
            fetchPeopleYouMayKnowUseCase: pymkUseCase,
            addFriendUseCase: addFriendUseCase,
            onRelationshipChanged: { _, _ in }
        )
        await pymkVM.load(currentUserId: UUID(), snapshot: nil)
        XCTAssertEqual(pymkVM.suggestions.count, 1)

        if let suggestion = pymkVM.suggestions.first {
            await pymkVM.sendFriendRequest(to: suggestion)
            XCTAssertTrue(pymkVM.suggestions.isEmpty)
        }

        // NearbyRadarSessionViewModel
        let nearbyUseCase = NearbyDiscoveryUseCase(repository: friendsRepo)
        let addFriendUseCaseRadar = AddFriendUseCase(repository: friendsRepo)
        let acceptReqRadar = AcceptFriendRequestUseCase(repository: friendsRepo)
        let cancelReqRadar = CancelFriendRequestUseCase(repository: friendsRepo)
        let fetchIncomingRadar = FetchIncomingFriendRequestsUseCase(repository: friendsRepo)
        let fetchOutgoingRadar = FetchOutgoingFriendRequestsUseCase(repository: friendsRepo)
        let nearbyVM = NearbyRadarSessionViewModel(
            nearbyDiscoveryUseCase: nearbyUseCase,
            addFriendUseCase: addFriendUseCaseRadar,
            acceptFriendRequestUseCase: acceptReqRadar,
            cancelFriendRequestUseCase: cancelReqRadar,
            fetchIncomingFriendRequestsUseCase: fetchIncomingRadar,
            fetchOutgoingFriendRequestsUseCase: fetchOutgoingRadar,
            languageService: langService
        )
        nearbyVM.stopRadarSession()
        XCTAssertFalse(nearbyVM.nearbyLoading)
    }
}
