import XCTest
import SwiftUI
import SplickDomain
import Common
import Localization
import Storage
@testable import FeatureMessaging

final class MessagingComposeAndTimeSeparatorTests: XCTestCase {

    // MARK: - NewMessageComposeViewModel Tests

    @MainActor
    func testNewMessageComposeViewModelDirectoryLoadingAndFilters() async {
        let currentUserId = UUID()
        let friend1 = UserSummary(id: UUID(), username: "alice", displayName: "Alice Wonderland", avatarURL: nil)
        let friend2 = UserSummary(id: UUID(), username: "bob_builder", displayName: "Bob B", avatarURL: nil)
        let group1 = Group(id: UUID(), name: "Travel Buddies", inviteCode: "TB123", createdBy: currentUserId)
        let group2 = Group(id: UUID(), name: "Foodies", inviteCode: "FD999", createdBy: currentUserId)

        let repo = MockSharePostMessagingRepository()
        let sendUseCase = SendMessageUseCase(repository: repo)
        let languageService = LanguageService(userDefaults: UserDefaultsService())

        let vm = NewMessageComposeViewModel(
            currentUserId: currentUserId,
            repository: repo,
            sendMessageUseCase: sendUseCase,
            friendsProvider: { [friend1, friend2] },
            groupsProvider: { [group1, group2] },
            searchUsersProvider: { query in
                [UserSummary(id: UUID(), username: "search_\(query)", displayName: "Search \(query)", avatarURL: nil)]
            },
            createSocialGroupWithMembers: { name, _ in
                Group(id: UUID(), name: name, inviteCode: "GRP", createdBy: currentUserId)
            },
            uploadImage: { _, _ in
                MessageImageAttachment(mediaId: UUID(), url: URL(string: "https://example.com/img.jpg")!, thumbnailURL: nil)
            },
            languageService: languageService
        )

        // Directory loading
        await vm.loadDirectoryIfNeeded()
        XCTAssertEqual(vm.friends.count, 2)
        XCTAssertEqual(vm.groups.count, 2)

        // Filtered friends
        XCTAssertEqual(vm.filteredFriends.count, 2)
        vm.searchQuery = "alice"
        XCTAssertEqual(vm.filteredFriends.count, 1)
        XCTAssertEqual(vm.filteredFriends.first?.username, "alice")
        vm.searchQuery = "builder"
        XCTAssertEqual(vm.filteredFriends.count, 1)

        // Filtered groups
        vm.searchQuery = "travel"
        XCTAssertEqual(vm.filteredGroups.count, 1)
        XCTAssertEqual(vm.filteredGroups.first?.name, "Travel Buddies")
        vm.searchQuery = "FD999"
        XCTAssertEqual(vm.filteredGroups.count, 1)

        // Reset search query
        vm.searchQuery = "   "
        XCTAssertEqual(vm.filteredFriends.count, 2)
        XCTAssertEqual(vm.filteredGroups.count, 2)
    }

    @MainActor
    func testNewMessageComposeViewModelDirectoryLoadingError() async {
        let repo = MockSharePostMessagingRepository()
        let sendUseCase = SendMessageUseCase(repository: repo)
        let languageService = LanguageService(userDefaults: UserDefaultsService())

        let vm = NewMessageComposeViewModel(
            currentUserId: UUID(),
            repository: repo,
            sendMessageUseCase: sendUseCase,
            friendsProvider: { throw URLError(.cannotConnectToHost) },
            groupsProvider: { throw URLError(.cannotConnectToHost) },
            searchUsersProvider: { _ in [] },
            createSocialGroupWithMembers: { name, _ in Group(id: UUID(), name: name, inviteCode: "G", createdBy: UUID()) },
            uploadImage: { _, _ in MessageImageAttachment(mediaId: UUID(), url: URL(string: "https://example.com/1.jpg")!, thumbnailURL: nil) },
            languageService: languageService
        )

        await vm.loadDirectoryIfNeeded()
        XCTAssertTrue(vm.friends.isEmpty)
        XCTAssertTrue(vm.groups.isEmpty)
    }

    @MainActor
    func testNewMessageComposeViewModelSelectionAndValidation() async {
        let currentUserId = UUID()
        let user1 = UserSummary(id: UUID(), username: "u1", displayName: "User One")
        let user2 = UserSummary(id: UUID(), username: "u2", displayName: "User Two")
        let currentUser = UserSummary(id: currentUserId, username: "me", displayName: "Me")
        let group = Group(id: UUID(), name: "Party", inviteCode: "P1", createdBy: currentUserId)

        let repo = MockSharePostMessagingRepository()
        let sendUseCase = SendMessageUseCase(repository: repo)
        let languageService = LanguageService(userDefaults: UserDefaultsService())

        let vm = NewMessageComposeViewModel(
            currentUserId: currentUserId,
            repository: repo,
            sendMessageUseCase: sendUseCase,
            friendsProvider: { [user1, user2] },
            groupsProvider: { [group] },
            searchUsersProvider: { query in
                [UserSummary(id: UUID(), username: "res_\(query)", displayName: "Res")]
            },
            createSocialGroupWithMembers: { name, _ in Group(id: UUID(), name: name, inviteCode: "G", createdBy: currentUserId) },
            uploadImage: { _, _ in MessageImageAttachment(mediaId: UUID(), url: URL(string: "https://example.com/1.jpg")!, thumbnailURL: nil) },
            languageService: languageService
        )

        // Toggle user
        XCTAssertFalse(vm.hasRecipients)
        XCTAssertFalse(vm.canSend)

        // Ignore current user
        vm.toggleUser(currentUser)
        XCTAssertFalse(vm.isUserSelected(currentUser))

        // Select user 1
        vm.toggleUser(user1)
        XCTAssertTrue(vm.isUserSelected(user1))
        XCTAssertTrue(vm.hasRecipients)

        // Toggle user 1 off
        vm.toggleUser(user1)
        XCTAssertFalse(vm.isUserSelected(user1))
        XCTAssertFalse(vm.hasRecipients)

        // Select user 1 again and remove user
        vm.toggleUser(user1)
        vm.removeUser(user1)
        XCTAssertFalse(vm.isUserSelected(user1))

        // Group selection (clears selected users)
        vm.toggleUser(user1)
        vm.selectGroup(group)
        XCTAssertEqual(vm.selectedGroup?.id, group.id)
        XCTAssertTrue(vm.selectedUsers.isEmpty)

        // Select same group deselects it
        vm.selectGroup(group)
        XCTAssertNil(vm.selectedGroup)

        // Select group again, then removeSelectedGroup
        vm.selectGroup(group)
        vm.removeSelectedGroup()
        XCTAssertNil(vm.selectedGroup)

        // Attachment draft states
        vm.toggleUser(user1)
        vm.messageBody = "Hello"
        XCTAssertTrue(vm.canSend)

        // Draft loading phase blocks send
        let loadingDraft = CommentAttachmentDraft(id: UUID(), kind: .image, phase: .loading)
        vm.attachmentDrafts = [loadingDraft]
        XCTAssertTrue(vm.isProcessingAttachments)
        XCTAssertFalse(vm.canSend)

        // Draft failed phase blocks send
        let failedDraft = CommentAttachmentDraft(id: UUID(), kind: .image, phase: .failed("Error"))
        vm.attachmentDrafts = [failedDraft]
        XCTAssertTrue(vm.hasFailedAttachments)
        XCTAssertFalse(vm.canSend)

        // Draft ready with submission allows send even if messageBody is empty
        vm.messageBody = "   "
        let readySubmission = CommentSubmissionAttachment(kind: .image, data: Data([1, 2]), mimeType: "image/jpeg", fileName: nil)
        let readyDraft = CommentAttachmentDraft(id: UUID(), kind: .image, phase: .ready, submission: readySubmission)
        vm.attachmentDrafts = [readyDraft]
        XCTAssertFalse(vm.isProcessingAttachments)
        XCTAssertFalse(vm.hasFailedAttachments)
        XCTAssertTrue(vm.canSend)

        // Search query empty clears remoteSearchUsers
        vm.onSearchQueryChanged("")
        XCTAssertTrue(vm.remoteSearchUsers.isEmpty)
        XCTAssertFalse(vm.isSearching)

        // Search query with content
        vm.onSearchQueryChanged("john")
        XCTAssertTrue(vm.isSearching)
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(vm.isSearching)
        XCTAssertFalse(vm.remoteSearchUsers.isEmpty)

        // Filtered remote users excludes friends and selected users
        _ = vm.filteredRemoteUsers
    }

    @MainActor
    func testNewMessageComposeViewModelSendFlows() async {
        let currentUserId = UUID()
        let friend = UserSummary(id: UUID(), username: "friend", displayName: "Friend Name", avatarURL: nil)
        let friend2 = UserSummary(id: UUID(), username: "friend2", displayName: "Friend Two", avatarURL: nil)
        let group = Group(
            id: UUID(),
            name: "Team",
            inviteCode: "T1",
            avatarURL: URL(string: "https://example.com/team.jpg"),
            members: [UserSummary(id: currentUserId, username: "me", displayName: "Me"), friend],
            createdBy: currentUserId
        )

        let repo = MockSharePostMessagingRepository()
        let sendUseCase = SendMessageUseCase(repository: repo)
        let languageService = LanguageService(userDefaults: UserDefaultsService())

        var uploadCount = 0
        let vm = NewMessageComposeViewModel(
            currentUserId: currentUserId,
            repository: repo,
            sendMessageUseCase: sendUseCase,
            friendsProvider: { [friend, friend2] },
            groupsProvider: { [group] },
            searchUsersProvider: { _ in [] },
            createSocialGroupWithMembers: { name, members in
                Group(id: UUID(), name: name, inviteCode: "SG", avatarURL: URL(string: "https://example.com/sg.jpg"), createdBy: currentUserId)
            },
            uploadImage: { _, _ in
                uploadCount += 1
                return MessageImageAttachment(mediaId: UUID(), url: URL(string: "https://example.com/uploaded.jpg")!, thumbnailURL: nil)
            },
            languageService: languageService
        )

        // Send without recipients returns nil
        let noRecipientsResult = await vm.send(submissions: [])
        XCTAssertNil(noRecipientsResult)
        XCTAssertNotNil(vm.errorMessage)

        // Composer clears the bound text before the async send reads it.
        vm.toggleUser(friend)
        vm.messageBody = "Hey there!"
        let capturedBody = vm.messageBody
        vm.messageBody = ""
        let capturedConv = await vm.send(body: capturedBody, submissions: [])
        XCTAssertNotNil(capturedConv)
        XCTAssertTrue(vm.messageBody.isEmpty)

        // Send with empty content returns nil
        vm.messageBody = "   "
        let emptyContentResult = await vm.send(submissions: [])
        XCTAssertNil(emptyContentResult)

        // 1. Send to single user success
        vm.messageBody = "Hello again!"
        let singleUserConv = await vm.send(submissions: [])
        XCTAssertNotNil(singleUserConv)
        XCTAssertTrue(vm.messageBody.isEmpty)

        // 2. Send to selected group success
        vm.selectGroup(group)
        vm.messageBody = "Group message"
        let groupConv = await vm.send(submissions: [])
        XCTAssertNotNil(groupConv)
        XCTAssertEqual(groupConv?.type, .group)

        // 3. Send to multiple users creates social group
        vm.toggleUser(friend)
        vm.toggleUser(friend2)
        vm.messageBody = "Multi user message"
        let multiConv = await vm.send(submissions: [])
        XCTAssertNotNil(multiConv)
        XCTAssertEqual(multiConv?.type, .group)

        // 4. Send with image submission needing upload
        vm.toggleUser(friend)
        vm.messageBody = "Photo"
        let imgSubmission = CommentSubmissionAttachment(kind: .image, data: Data([1, 2, 3]), mimeType: "image/jpeg", fileName: nil)
        let imgConv = await vm.send(submissions: [imgSubmission])
        XCTAssertNotNil(imgConv)
        XCTAssertEqual(uploadCount, 1)

        // 5. Send with media submission failure (empty attachments)
        let vmFailingUpload = NewMessageComposeViewModel(
            currentUserId: currentUserId,
            repository: repo,
            sendMessageUseCase: sendUseCase,
            friendsProvider: { [friend] },
            groupsProvider: { [] },
            searchUsersProvider: { _ in [] },
            createSocialGroupWithMembers: { name, _ in Group(id: UUID(), name: name, inviteCode: "G", createdBy: currentUserId) },
            uploadImage: { _, _ in throw URLError(.badServerResponse) },
            languageService: languageService
        )
        vmFailingUpload.toggleUser(friend)
        vmFailingUpload.messageBody = "Photo fail"
        let failConv = await vmFailingUpload.send(submissions: [imgSubmission])
        XCTAssertNil(failConv)
        XCTAssertNotNil(vmFailingUpload.errorMessage)
    }

    // MARK: - SharePostViewModel Additional Tests

    @MainActor
    func testSharePostViewModelAdditionalBranches() async {
        let shareUrl = URL(string: "https://splick.app/p/123")!
        let repo = MockSharePostMessagingRepository()
        let fetchConvUseCase = FetchConversationsUseCase(repository: repo)
        let sendUseCase = SendMessageUseCase(repository: repo)
        let shareUseCase = SharePostToChatUseCase(repository: repo, sendMessageUseCase: sendUseCase)
        let languageService = LanguageService(userDefaults: UserDefaultsService())

        let vm = SharePostViewModel(
            shareURL: shareUrl,
            currentUserId: UUID(),
            shareUseCase: shareUseCase,
            fetchConversationsUseCase: fetchConvUseCase,
            friendsProvider: { [] },
            searchUsersProvider: { query in
                if query == "fail" { throw URLError(.timedOut) }
                return [UserSummary(id: UUID(), username: "u", displayName: "User")]
            },
            languageService: languageService
        )

        // Empty search query
        vm.onSearchQueryChanged("")
        XCTAssertTrue(vm.remoteSearchUsers.isEmpty)

        // Search query failure branch
        vm.onSearchQueryChanged("fail")
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(vm.remoteSearchUsers.isEmpty)
        XCTAssertFalse(vm.isSearching)
    }

    @MainActor
    func testSharePostViewModelFactoryEnvironment() {
        var env = EnvironmentValues()
        XCTAssertNil(env.makeSharePostViewModel)
        env.makeSharePostViewModel = { url in
            let repo = MockSharePostMessagingRepository()
            let fetchConvUseCase = FetchConversationsUseCase(repository: repo)
            let sendUseCase = SendMessageUseCase(repository: repo)
            let shareUseCase = SharePostToChatUseCase(repository: repo, sendMessageUseCase: sendUseCase)
            return SharePostViewModel(
                shareURL: url,
                currentUserId: UUID(),
                shareUseCase: shareUseCase,
                fetchConversationsUseCase: fetchConvUseCase,
                friendsProvider: { [] },
                searchUsersProvider: { _ in [] },
                languageService: LanguageService(userDefaults: UserDefaultsService())
            )
        }
        XCTAssertNotNil(env.makeSharePostViewModel)
    }

    // MARK: - ConversationMutePreset+L10n Tests

    func testConversationMutePresetTitleKeys() {
        XCTAssertEqual(ConversationMutePreset.fifteenMinutes.titleKey, .messagingChatMute15Minutes)
        XCTAssertEqual(ConversationMutePreset.oneHour.titleKey, .messagingChatMute1Hour)
        XCTAssertEqual(ConversationMutePreset.eightHours.titleKey, .messagingChatMute8Hours)
        XCTAssertEqual(ConversationMutePreset.twentyFourHours.titleKey, .messagingChatMute24Hours)
        XCTAssertEqual(ConversationMutePreset.untilSevenAM.titleKey, .messagingChatMuteUntil7Am)
        XCTAssertEqual(ConversationMutePreset.forever.titleKey, .messagingChatMuteForever)
    }

    // MARK: - GroupSystemNoticePayload Tests

    func testGroupSystemNoticePayloadParsing() {
        let leftBody = "\(GroupSystemNoticePayload.memberLeftPrefix) Sarah"
        XCTAssertTrue(GroupSystemNoticePayload.isMemberLeft(leftBody))
        XCTAssertEqual(GroupSystemNoticePayload.memberLeftDisplayName(leftBody), "Sarah")

        XCTAssertFalse(GroupSystemNoticePayload.isMemberLeft("Hello world"))
        XCTAssertFalse(GroupSystemNoticePayload.isMemberLeft(nil))
        XCTAssertEqual(GroupSystemNoticePayload.memberLeftDisplayName("Hello world"), "Hello world")
        XCTAssertEqual(GroupSystemNoticePayload.memberLeftDisplayName(nil), "")

        let noticeMsg = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: UUID(),
            body: "Notice",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .groupMemberLeft
        )
        XCTAssertTrue(GroupSystemNoticePayload.displaysAsSystemNotice(noticeMsg))

        let leftMsg = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: UUID(),
            body: leftBody,
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .user
        )
        XCTAssertTrue(GroupSystemNoticePayload.displaysAsSystemNotice(leftMsg))

        let normalMsg = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: UUID(),
            body: "Just chatting",
            clientMessageId: UUID(),
            createdAt: Date(),
            type: .user
        )
        XCTAssertFalse(GroupSystemNoticePayload.displaysAsSystemNotice(normalMsg))
    }

    // MARK: - MessageTimeSeparatorFormatter Tests

    func testMessageTimeSeparatorFormatterBranches() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let now = Date(timeIntervalSince1970: 1726848000) // 2024-09-20 16:00:00 UTC

        // 1. Same day
        let sameDay = now.addingTimeInterval(-3600)
        let sameDayFormatted = MessageTimeSeparatorFormatter.string(
            from: sameDay,
            locale: .en,
            yesterdayLabel: "Yesterday",
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(sameDayFormatted, "15:00")

        // 2. Yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayFormatted = MessageTimeSeparatorFormatter.string(
            from: yesterday,
            locale: .en,
            yesterdayLabel: "Yesterday",
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(yesterdayFormatted.hasPrefix("Yesterday"))

        // 3. Within 7 days (3 days ago)
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let threeDaysFormatted = MessageTimeSeparatorFormatter.string(
            from: threeDaysAgo,
            locale: .en,
            yesterdayLabel: "Yesterday",
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(threeDaysFormatted.isEmpty)

        // 4. Same year, more than 7 days ago
        let twentyDaysAgo = calendar.date(byAdding: .day, value: -20, to: now)!
        let twentyDaysFormatted = MessageTimeSeparatorFormatter.string(
            from: twentyDaysAgo,
            locale: .en,
            yesterdayLabel: "Yesterday",
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(twentyDaysFormatted.isEmpty)

        // 5. Different year
        let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
        let lastYearFormatted = MessageTimeSeparatorFormatter.string(
            from: lastYear,
            locale: .en,
            yesterdayLabel: "Yesterday",
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(lastYearFormatted.isEmpty)
    }

    // MARK: - ConversationPreviewFormatter Tests

    func testConversationPreviewFormatterAdditionalCases() {
        let myId = UUID()
        let peerId = UUID()

        // Recalled message
        let recalledMsg = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: peerId,
            body: "Secret",
            clientMessageId: UUID(),
            createdAt: Date(),
            recalled: true
        )
        XCTAssertEqual(ConversationPreviewFormatter.content(for: recalledMsg), .recalled)

        // Sender label branches
        let myMsg = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: myId,
            body: "Hi",
            clientMessageId: UUID(),
            createdAt: Date()
        )
        let labelMe = ConversationPreviewFormatter.senderLabel(
            for: myMsg,
            currentUserId: myId,
            meLabel: "You",
            fallbackDisplayName: nil,
            unknownLabel: "Unknown"
        )
        XCTAssertEqual(labelMe, "You")

        let peerMsgNoName = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: peerId,
            senderDisplayName: nil,
            body: "Hi",
            clientMessageId: UUID(),
            createdAt: Date()
        )
        let labelFallback = ConversationPreviewFormatter.senderLabel(
            for: peerMsgNoName,
            currentUserId: myId,
            meLabel: "You",
            fallbackDisplayName: "John Doe",
            unknownLabel: "Unknown"
        )
        XCTAssertEqual(labelFallback, "Doe")

        let labelUnknown = ConversationPreviewFormatter.senderLabel(
            for: peerMsgNoName,
            currentUserId: myId,
            meLabel: "You",
            fallbackDisplayName: nil,
            unknownLabel: "Someone"
        )
        XCTAssertEqual(labelUnknown, "Someone")
    }
}
