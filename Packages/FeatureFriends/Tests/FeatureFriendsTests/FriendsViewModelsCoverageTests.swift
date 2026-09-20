import XCTest
import SplickDomain
import Common
import Storage
import FeatureMedia
import Localization
@testable import FeatureFriends

@MainActor
final class FriendsViewModelsCoverageTests: XCTestCase {

    private final class MockStorage: UserDefaultsServiceProtocol {
        private var storage: [String: Any] = [:]
        func set<T: Codable>(_ value: T, for key: String) { storage[key] = value }
        func get<T: Codable>(for key: String) -> T? { storage[key] as? T }
        func setBool(_ value: Bool, for key: String) { storage[key] = value }
        func getBool(for key: String) -> Bool { (storage[key] as? Bool) ?? false }
        func remove(for key: String) { storage.removeValue(forKey: key) }
    }

    private actor MockAddFriendUseCase: AddFriendUseCaseProtocol {
        var shouldFail = false
        func execute(username: String, message: String?) async throws -> UserSummary {
            if shouldFail { throw FriendsError.userNotFound }
            return UserSummary(id: UUID(), username: username, displayName: username, avatarURL: nil)
        }
        func executeFromQRCode(_ payload: String, message: String?) async throws -> UserSummary {
            if shouldFail { throw FriendsError.invalidQRCode }
            return UserSummary(id: UUID(), username: "qr_user", displayName: "QR User", avatarURL: nil)
        }
    }

    private actor MockUploadAvatarUseCase: UploadGroupAvatarUseCaseProtocol {
        func execute(image: UIImage, groupId: UUID) async throws -> MediaUploadResult {
            MediaUploadResult(id: UUID(), url: URL(string: "https://example.com/avatar.jpg")!, thumbnailURL: nil, sizeBytes: 1024)
        }
        func execute(imageData: Data, groupId: UUID) async throws -> MediaUploadResult {
            MediaUploadResult(id: UUID(), url: URL(string: "https://example.com/avatar.jpg")!, thumbnailURL: nil, sizeBytes: 1024)
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

    private actor MockGroupsRepo: GroupsRepositoryProtocol {
        func fetchMyGroups() async throws -> [Group] { [] }
        func fetchGroup(groupId: UUID) async throws -> Group {
            Group(id: groupId, name: "G", inviteCode: "C", description: nil, avatarURL: nil, members: [], createdBy: UUID())
        }
        func fetchGroupMembers(groupId: UUID, status: String?) async throws -> [GroupMemberItem] { [] }
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
            GroupServerQR(id: UUID(), payload: "group_qr", groupId: groupId, issuedAt: Date(), expiresAt: Date().addingTimeInterval(300))
        }
        func revokeGroupQr(groupId: UUID, qrId: UUID) async throws {}
        func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult {
            InviteFriendsToGroupResult(invited: userIds, skipped: [])
        }
        func joinGroup(inviteCode: String) async throws -> Group {
            Group(id: UUID(), name: "Joined", inviteCode: inviteCode, description: nil, avatarURL: nil, members: [], createdBy: UUID())
        }
        func joinGroupFromQRCode(_ payload: String) async throws -> Group {
            Group(id: UUID(), name: "Joined QR", inviteCode: "QR", description: nil, avatarURL: nil, members: [], createdBy: UUID())
        }
        func approvePendingMember(groupId: UUID, memberRowId: UUID) async throws {}
        func rejectPendingMember(groupId: UUID, memberRowId: UUID) async throws {}
        func removeMember(groupId: UUID, memberRowId: UUID) async throws {}
        func leaveGroup(groupId: UUID) async throws {}
        func transferOwnership(groupId: UUID, newOwnerId: UUID) async throws -> Group {
            Group(id: groupId, name: "Transferred", inviteCode: "C", description: nil, avatarURL: nil, members: [], createdBy: UUID())
        }
    }

    private var languageService: LanguageService!

    override func setUp() {
        super.setUp()
        languageService = LanguageService(userDefaults: MockStorage())
    }

    func testAddFriendViewModel() async {
        let useCase = MockAddFriendUseCase()
        var successCalled = false
        let vm = AddFriendViewModel(
            addFriendUseCase: useCase,
            languageService: languageService,
            onSuccess: { successCalled = true }
        )

        await vm.addByUsername()
        XCTAssertNotNil(vm.errorMessage)

        vm.username = "alice"
        await vm.addByUsername()
        XCTAssertTrue(successCalled)
        XCTAssertNotNil(vm.successMessage)

        successCalled = false
        await vm.addFromQR("splick://add-friend/bob")
        XCTAssertTrue(successCalled)
    }

    func testCreateGroupViewModel() async {
        let repo = MockGroupsRepo()
        let friendsRepo = MockFriendsRepo()
        let uploadAvatar = MockUploadAvatarUseCase()

        let fetchFriends = FetchMyFriendsUseCase(repository: friendsRepo)
        let createGroup = CreateGroupUseCase(repository: repo)
        let inviteFriends = InviteFriendsToGroupUseCase(repository: repo)
        let updateAvatar = UpdateGroupAvatarUseCase(repository: repo)

        var createdGroup: Group?
        let vm = CreateGroupViewModel(
            friends: [],
            fetchMyFriendsUseCase: fetchFriends,
            createGroupUseCase: createGroup,
            inviteFriendsUseCase: inviteFriends,
            uploadGroupAvatarUseCase: uploadAvatar,
            updateGroupAvatarUseCase: updateAvatar,
            languageService: languageService,
            onSuccess: { g, _ in createdGroup = g }
        )

        vm.name = "My New Group"
        vm.groupDescription = "Test Description"
        await vm.create()

        XCTAssertNotNil(createdGroup)
        XCTAssertEqual(createdGroup?.name, "My New Group")
    }

    func testEditGroupViewModel() async {
        let repo = MockGroupsRepo()
        let uploadAvatar = MockUploadAvatarUseCase()
        let updateGroupUseCase = UpdateGroupUseCase(repository: repo)
        let updateAvatarUseCase = UpdateGroupAvatarUseCase(repository: repo)
        let group = Group(id: UUID(), name: "Old Group", inviteCode: "C", description: nil, avatarURL: nil, members: [], createdBy: UUID())

        let vm = EditGroupViewModel(
            group: group,
            updateGroupUseCase: updateGroupUseCase,
            updateGroupAvatarUseCase: updateAvatarUseCase,
            uploadGroupAvatarUseCase: uploadAvatar,
            languageService: languageService
        )

        vm.name = "Updated Group Name"
        let saved = await vm.save()
        XCTAssertNotNil(saved)
    }

    func testJoinGroupViewModel() async {
        let repo = MockGroupsRepo()
        let joinUseCase = JoinGroupUseCase(repository: repo)
        var joined = false
        let vm = JoinGroupViewModel(
            joinGroupUseCase: joinUseCase,
            languageService: languageService,
            onSuccess: { joined = true }
        )

        vm.inviteCode = "INVITE1234"
        await vm.joinByCode()
        XCTAssertTrue(joined)

        joined = false
        await vm.joinFromQR("splick://join-group/INVITE1234")
        XCTAssertTrue(joined)
    }

    func testGroupInviteQRViewModel() async {
        let repo = MockGroupsRepo()
        let genQr = GenerateGroupQrUseCase(repository: repo)
        let revokeQr = RevokeGroupQrUseCase(repository: repo)
        let groupId = UUID()

        let vm = GroupInviteQRViewModel(
            groupId: groupId,
            generateGroupQrUseCase: genQr,
            revokeGroupQrUseCase: revokeQr,
            languageService: languageService
        )

        await vm.load()
        XCTAssertNotNil(vm.serverQR)
        XCTAssertNotNil(vm.qrPayload)

        await vm.refresh()
        XCTAssertNotNil(vm.serverQR)
    }

    func testInviteFriendsToGroupViewModel() async {
        let repo = MockGroupsRepo()
        let friendsRepo = MockFriendsRepo()
        let fetchFriends = FetchMyFriendsUseCase(repository: friendsRepo)
        let searchUsers = SearchUsersUseCase(repository: friendsRepo)
        let addFriend = AddFriendUseCase(repository: friendsRepo)
        let inviteUseCase = InviteFriendsToGroupUseCase(repository: repo)
        let groupId = UUID()

        var invitedCount = 0
        let vm = InviteFriendsToGroupViewModel(
            groupId: groupId,
            existingMemberIds: [],
            currentUserId: UUID(),
            fetchMyFriendsUseCase: fetchFriends,
            searchUsersUseCase: searchUsers,
            addFriendUseCase: addFriend,
            inviteFriendsUseCase: inviteUseCase,
            languageService: languageService,
            onInvited: { ids, _ in invitedCount = ids.count }
        )

        let friendId = UUID()
        vm.toggleSelection(friendId)
        XCTAssertTrue(vm.selectedIds.contains(friendId))

        await vm.submit(shareChatHistory: true)
        XCTAssertEqual(invitedCount, 1)
    }
}
