import XCTest
import UIKit
import SplickDomain
import Common
import Storage
import Localization
import FeatureFriends
import FeatureMedia
@testable import FeatureSocialFeed

final class MockUserDefaultsService: UserDefaultsServiceProtocol {
    private var storage: [String: Any] = [:]
    func set<T: Codable>(_ value: T, for key: String) { storage[key] = value }
    func get<T: Codable>(for key: String) -> T? { storage[key] as? T }
    func setBool(_ value: Bool, for key: String) { storage[key] = value }
    func getBool(for key: String) -> Bool { (storage[key] as? Bool) ?? false }
    func remove(for key: String) { storage.removeValue(forKey: key) }
}

final class MockFetchFriendsUseCase: FetchFriendsUseCaseProtocol, @unchecked Sendable {
    var friendsToReturn: [UserSummary] = []
    var lastQuery: String?
    var lastPage: Int?
    var lastLimit: Int?

    func execute(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        lastQuery = query
        lastPage = page
        lastLimit = limit
        return friendsToReturn
    }
}

final class MockFetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol, @unchecked Sendable {
    var groupsToReturn: [Group] = []

    func execute() async throws -> [Group] {
        return groupsToReturn
    }
}

final class MockFetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol, @unchecked Sendable {
    var membersToReturn: [GroupMemberItem] = []

    func execute(groupId: UUID, status: String?) async throws -> [GroupMemberItem] {
        return membersToReturn
    }
}

@MainActor
final class CreatePostComposeViewModelTests: XCTestCase {
    private var mockFriendsUseCase: MockFetchFriendsUseCase!
    private var mockGroupsUseCase: MockFetchMyGroupsUseCase!
    private var mockMembersUseCase: MockFetchGroupMembersUseCase!
    private var mockFeedRepo: MockFeedRepository!
    private var languageService: LanguageService!
    private var currentUser: UserSummary!

    override func setUp() {
        super.setUp()
        mockFriendsUseCase = MockFetchFriendsUseCase()
        mockGroupsUseCase = MockFetchMyGroupsUseCase()
        mockMembersUseCase = MockFetchGroupMembersUseCase()
        mockFeedRepo = MockFeedRepository()
        let userDefaults = MockUserDefaultsService()
        languageService = LanguageService(userDefaults: userDefaults)
        currentUser = UserSummary(id: UUID(), username: "tester", displayName: "Test User", avatarURL: nil)
    }

    private func makeViewModel(images: [UIImage] = []) -> CreatePostComposeViewModel {
        CreatePostComposeViewModel(
            previewImages: images,
            previewVideoURL: nil,
            previewVideoURLs: [],
            fetchFriendsUseCase: mockFriendsUseCase,
            fetchMyGroupsUseCase: mockGroupsUseCase,
            fetchGroupMembersUseCase: mockMembersUseCase,
            languageService: languageService,
            currentUser: currentUser,
            currentUserId: currentUser.id,
            feedRepository: mockFeedRepo
        )
    }

    func testInitialStateAndSlots() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.remainingMediaSlots, 10)
        XCTAssertEqual(vm.remainingImageSlots, 10)
        XCTAssertTrue(vm.canAddMoreMedia)
        XCTAssertEqual(vm.composerUser?.id, currentUser.id)
        XCTAssertEqual(vm.audienceMode, .friends)
        XCTAssertFalse(vm.enableBillSplit)
        XCTAssertEqual(vm.splitMode, .equal)
        XCTAssertNil(vm.parsedBillTotal)
        XCTAssertNil(vm.equalShareAmount)
        XCTAssertNil(vm.equalSharePreview)
    }

    func testAddAndRemoveMediaDrafts() {
        let vm = makeViewModel()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let testImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }

        vm.addImages([testImage])
        XCTAssertEqual(vm.selectedMediaItems.count, 1)
        XCTAssertEqual(vm.remainingMediaSlots, 9)

        guard let first = vm.selectedMediaItems.first else {
            XCTFail("Missing item")
            return
        }

        let newImage = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        vm.updateMediaImage(id: first.id, image: newImage)
        XCTAssertEqual(vm.selectedMediaItems.count, 1)

        vm.removeMediaItem(id: first.id)
        XCTAssertEqual(vm.selectedMediaItems.count, 0)
        XCTAssertEqual(vm.remainingMediaSlots, 10)
    }

    func testPendingGuestValidationAndFormatting() {
        let vm = makeViewModel()
        
        // Invalid email format
        vm.addPendingGuest(displayName: "Bob", email: "invalid-email")
        XCTAssertTrue(vm.pendingGuests.isEmpty)

        // Valid email
        vm.addPendingGuest(displayName: "Bob", email: "bob@example.com")
        XCTAssertEqual(vm.pendingGuests.count, 1)
        XCTAssertEqual(vm.pendingGuests.first?.displayName, "Bob")
        XCTAssertEqual(vm.pendingGuests.first?.email, "bob@example.com")

        // Auto display name from email when name is blank
        vm.addPendingGuest(displayName: "", email: "alice.smith@example.com")
        XCTAssertEqual(vm.pendingGuests.count, 2)
        XCTAssertEqual(vm.pendingGuests.last?.displayName, "alice smith")

        if let first = vm.pendingGuests.first {
            vm.removePendingGuest(first)
            XCTAssertEqual(vm.pendingGuests.count, 1)
            XCTAssertEqual(vm.pendingGuests.first?.displayName, "alice smith")
        }
    }

    func testBillSplitCalculationsEqualMode() {
        let vm = makeViewModel()
        let friend = UserSummary(id: UUID(), username: "friend1", displayName: "Friend 1", avatarURL: nil)
        vm.addCompanion(friend)
        vm.addPendingGuest(displayName: "Guest 1", email: "guest1@example.com")

        vm.enableBillSplit = true
        vm.billTotalText = "300000"

        XCTAssertEqual(vm.parsedBillTotal, Decimal(300000))
        XCTAssertNil(vm.billTotalAmountError)

        // 3 participants: currentUser, friend1, guest1
        XCTAssertEqual(vm.billSplitParticipants.count, 2) // currentUser + friend1
        XCTAssertEqual(vm.equalShareAmount, Decimal(100000))
        XCTAssertNotNil(vm.equalSharePreview)

        // Amount below minimum
        vm.billTotalText = "500"
        XCTAssertNotNil(vm.billTotalAmountError)
    }

    func testBillSplitPercentageAndExactMode() {
        let vm = makeViewModel()
        let friendId = UUID()
        let friend = UserSummary(id: friendId, username: "friend1", displayName: "Friend 1", avatarURL: nil)
        vm.addCompanion(friend)

        vm.enableBillSplit = true
        vm.billTotalText = "1000000"
        vm.splitMode = .percentage
        vm.setPercentage(userId: currentUser.id, raw: "25")

        XCTAssertEqual(vm.amountForPercentage(userId: currentUser.id), Decimal(250000))
        XCTAssertEqual(vm.percentageTexts[currentUser.id], "25")
        XCTAssertEqual(vm.percentageTexts[friendId], "75")

        vm.splitMode = .exact
        vm.setExactAmount(userId: currentUser.id, raw: "400000")
        XCTAssertEqual(vm.exactAmountTexts[currentUser.id], VNDMoneyFormat.format(400_000))
        XCTAssertEqual(vm.exactAmountTexts[friendId], VNDMoneyFormat.format(600_000))
    }

    func testCompanionAndGroupSelection() async {
        let vm = makeViewModel()
        let friend = UserSummary(id: UUID(), username: "friend1", displayName: "Friend 1", avatarURL: nil)
        
        vm.addCompanion(friend)
        XCTAssertTrue(vm.selectedCompanionIds.contains(friend.id))
        XCTAssertTrue(vm.companionUsersForSubmit.contains(where: { $0.id == friend.id }))

        vm.removeCompanion(friend)
        XCTAssertFalse(vm.selectedCompanionIds.contains(friend.id))

        let groupMember = UserSummary(id: UUID(), username: "member1", displayName: "Member 1", avatarURL: nil)
        let group = Group(
            id: UUID(),
            name: "Weekend Squad",
            inviteCode: "WEEKEND",
            description: "Fun group",
            avatarURL: nil,
            members: [groupMember],
            memberCount: 1,
            createdBy: currentUser.id,
            createdAt: Date()
        )

        mockGroupsUseCase.groupsToReturn = [group]
        mockMembersUseCase.membersToReturn = [
            GroupMemberItem(
                id: UUID(),
                userId: groupMember.id,
                username: groupMember.username,
                displayName: groupMember.displayName,
                avatarURL: nil,
                role: "MEMBER",
                status: "ACTIVE"
            )
        ]

        vm.selectCompanionGroup(group)
        XCTAssertTrue(vm.selectedCompanionGroupIds.contains(group.id))
        XCTAssertEqual(vm.companionGroupDisplayName, "Weekend Squad")

        vm.toggleCompanionGroupMembersExpanded(group)
        XCTAssertTrue(vm.isCompanionGroupMembersExpanded(group))

        vm.removeCompanionGroup(group)
        XCTAssertFalse(vm.selectedCompanionGroupIds.contains(group.id))
        XCTAssertNil(vm.companionGroupDisplayName)
    }

    func testAudienceModesAndSummaries() async {
        let vm = makeViewModel()
        XCTAssertEqual(vm.audienceMode, .friends)
        XCTAssertFalse(vm.audienceSummaryTitle.isEmpty)
        XCTAssertFalse(vm.audienceSummarySubtitle.isEmpty)

        let targetUser = UserSummary(id: UUID(), username: "alice", displayName: "Alice", avatarURL: nil)
        let targetGroup = Group(
            id: UUID(),
            name: "Besties",
            inviteCode: "BEST",
            description: nil,
            avatarURL: nil,
            members: [],
            memberCount: 2,
            createdBy: currentUser.id,
            createdAt: Date()
        )

        mockGroupsUseCase.groupsToReturn = [targetGroup]

        vm.selectAudienceMode(.groups)
        XCTAssertEqual(vm.audienceMode, .groups)
        vm.toggleAudienceGroup(targetGroup)
        XCTAssertTrue(vm.isAudienceGroupSelected(targetGroup))
        XCTAssertFalse(vm.audienceSummaryTitle.isEmpty)
        vm.removeAudienceGroup(targetGroup)
        XCTAssertFalse(vm.isAudienceGroupSelected(targetGroup))

        vm.selectAudienceMode(.specificUsers)
        XCTAssertEqual(vm.audienceMode, .specificUsers)
        vm.toggleAudienceUser(targetUser)
        XCTAssertTrue(vm.isAudienceUserSelected(targetUser))
        XCTAssertFalse(vm.audienceSummaryTitle.isEmpty)
        vm.removeAudienceUser(targetUser)
        XCTAssertFalse(vm.isAudienceUserSelected(targetUser))

        vm.selectAudienceMode(.friendsExcept)
        XCTAssertEqual(vm.audienceMode, .friendsExcept)
    }

    func testLocationPlaceHandling() {
        let vm = makeViewModel()
        vm.location = "Saigon Central"
        vm.useTypedLocation()
        XCTAssertEqual(vm.selectedPlace?.displayName, "Saigon Central")

        let place = PostPlace(
            placeId: "p1",
            displayName: "Landmark 81",
            lat: 10.795,
            lon: 106.721
        )
        vm.selectPlace(place)
        XCTAssertEqual(vm.selectedPlace?.displayName, "Landmark 81")
        XCTAssertEqual(vm.location, "Landmark 81")

        vm.onLocationPermissionDenied()
        XCTAssertFalse(vm.locationGpsAvailable)
    }

    func testPrepareSubmitValidation() {
        let vm = makeViewModel()
        
        // Fails with no media
        let submit1 = vm.prepareSubmit()
        XCTAssertNil(submit1)
        if case .failed = vm.submitState {
            // Expected
        } else {
            XCTFail("Should fail because no media is selected")
        }

        // Add media draft
        let draft = ComposeMediaDraft(
            previewImage: nil,
            mediaType: .image,
            data: Data("fake_jpg".utf8),
            mimeType: "image/jpeg",
            videoDurationSeconds: nil
        )
        vm.addMediaDraft(draft)

        // Audience is .friends, no bill split -> Success!
        let submit2 = vm.prepareSubmit()
        XCTAssertNotNil(submit2)
        XCTAssertEqual(submit2?.input.mediaItems.count, 1)
        XCTAssertEqual(submit2?.input.feedKind, .checkIn)

        // Bill split enabled without companions -> Fails
        vm.enableBillSplit = true
        let submit3 = vm.prepareSubmit()
        XCTAssertNil(submit3)

        // Add companion & valid bill total -> Success
        let companion = UserSummary(id: UUID(), username: "comp", displayName: "Companion", avatarURL: nil)
        vm.addCompanion(companion)
        vm.billTotalText = "150000"
        let submit4 = vm.prepareSubmit()
        XCTAssertNotNil(submit4)
        XCTAssertEqual(submit4?.input.feedKind, .shareBill)
        XCTAssertEqual(submit4?.input.billSplit?.totalAmount, Decimal(150000))
    }

    func testVideoDraftKeepsSourceURLForPreview() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("compose-preview.mp4")
        try Data([0, 1, 2, 3, 4, 5, 6, 7]).write(to: url)
        let vm = makeViewModel()
        vm.addVideo(url: url)
        XCTAssertEqual(vm.selectedMediaItems.count, 1)
        XCTAssertEqual(vm.selectedMediaItems.first?.mediaType, .video)
        XCTAssertEqual(vm.selectedMediaItems.first?.sourceURL, url)
        XCTAssertEqual(vm.selectedMediaItems.first?.previewPlaybackURL, url)
        XCTAssertTrue(vm.selectedMediaItems.first?.data.isEmpty == true)
        XCTAssertFalse(vm.hasEncodingMedia)
    }

    func testPendingVideoEncodeBlocksSubmitUntilReady() {
        let frames = (0..<8).map { _ in
            UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { ctx in
                UIColor.red.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
            }
        }
        let pending = PendingCapturedVideo(frames: frames, pingPong: false, previewImage: frames.first)
        let vm = CreatePostComposeViewModel(
            pendingVideoEncodes: [pending],
            fetchFriendsUseCase: mockFriendsUseCase,
            fetchMyGroupsUseCase: mockGroupsUseCase,
            fetchGroupMembersUseCase: mockMembersUseCase,
            languageService: languageService,
            currentUser: currentUser,
            currentUserId: currentUser.id
        )
        XCTAssertEqual(vm.selectedMediaItems.count, 1)
        XCTAssertTrue(vm.hasEncodingMedia)
        XCTAssertFalse(vm.canSubmitPost)
        XCTAssertNil(vm.prepareSubmit())
    }

    func testCompanionDirectoryLoadsFriendsWithoutActivatingSearch() async {
        let friend = UserSummary(id: UUID(), username: "lan", displayName: "Lan", avatarURL: nil)
        mockFriendsUseCase.friendsToReturn = [friend]
        let vm = makeViewModel()

        await vm.preloadFriendSuggestionsIfNeeded()

        XCTAssertFalse(vm.isFriendSearchActive)
        XCTAssertTrue(vm.shouldShowFriendSuggestions)
        XCTAssertEqual(vm.friendSearchResults.map(\.id), [friend.id])
        XCTAssertEqual(mockFriendsUseCase.lastQuery, "")
        XCTAssertEqual(mockFriendsUseCase.lastPage, 0)
    }
}
