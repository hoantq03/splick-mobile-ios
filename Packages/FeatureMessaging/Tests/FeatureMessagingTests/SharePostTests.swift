import XCTest
import SplickDomain
import Common
import Localization
@testable import FeatureMessaging

import Storage

private final class MockUserDefaultsService: UserDefaultsServiceProtocol {
    private var dict: [String: Any] = [:]
    func set<T: Codable>(_ value: T, for key: String) { dict[key] = value }
    func get<T: Codable>(for key: String) -> T? { dict[key] as? T }
    func setBool(_ value: Bool, for key: String) { dict[key] = value }
    func getBool(for key: String) -> Bool { (dict[key] as? Bool) ?? false }
    func remove(for key: String) { dict.removeValue(forKey: key) }
}

struct MockSharePostMessagingRepository: MessagingRepositoryProtocol, @unchecked Sendable {
    var sendMessageResult: Result<ChatMessage, Error> = .success(
        ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            senderId: UUID(),
            body: "test",
            clientMessageId: UUID(),
            createdAt: Date()
        )
    )

    func fetchConversations(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation> {
        MessagingPage(items: [], hasMore: false)
    }

    func fetchConversationInboxSummary() async throws -> Int { 0 }

    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        Conversation(
            id: UUID(),
            type: .direct,
            unreadCount: 0,
            peer: ConversationPeer(userId: friendUserId, username: "user_\(friendUserId.uuidString.prefix(4))", displayName: nil, avatarUrl: nil),
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func createGroup(name: String, avatarUrl: String?, memberUserIds: [UUID], groupId: UUID?) async throws -> Conversation {
        Conversation(
            id: groupId ?? UUID(),
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: name,
            groupAvatarUrl: avatarUrl,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func addGroupMember(groupId: UUID, memberUserId: UUID, shareChatHistory: Bool) async throws {}
    func listGroupMembers(groupId: UUID) async throws -> [GroupChatMember] { [] }
    func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws {}
    func leaveGroup(groupId: UUID) async throws {}
    func deleteConversation(conversationId: UUID) async throws {}

    func updateNotificationSettings(
        conversationId: UUID,
        notificationsEnabled: Bool,
        notificationSound: String,
        mutedUntil: Date?
    ) async throws -> Conversation {
        fatalError()
    }

    func renameGroup(groupId: UUID, name: String) async throws -> Conversation { fatalError() }
    func updateGroupAvatar(groupId: UUID, avatarUrl: String) async throws -> Conversation { fatalError() }
    func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws {}

    func fetchMessages(conversationId: UUID, page: Int, limit: Int, after: Int64?, before: Int64?) async throws -> MessagingPage<ChatMessage> {
        MessagingPage(items: [], hasMore: false)
    }

    func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment],
        replyToMessageId: UUID?
    ) async throws -> ChatMessage {
        switch sendMessageResult {
        case .success(let msg): return msg
        case .failure(let err): throw err
        }
    }

    func editMessage(conversationId: UUID, messageId: UUID, body: String) async throws -> ChatMessage { fatalError() }
    func recallMessage(conversationId: UUID, messageId: UUID) async throws {}
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws {}
    func unreadCount() async throws -> Int { 0 }
    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction { fatalError() }
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws {}
    func searchMessages(query: String, page: Int, limit: Int, conversationId: UUID?) async throws -> [MessageSearchHit] { [] }
    func requestWsTicket() async throws -> String { "ticket" }
}

final class SharePostTests: XCTestCase {

    func testSharePostRecipientProperties() {
        let convId = UUID()
        let peerId = UUID()
        let directConv = Conversation(
            id: convId,
            type: .direct,
            unreadCount: 0,
            peer: ConversationPeer(userId: peerId, username: "alice", displayName: "Alice Smith", avatarUrl: "https://example.com/a.jpg"),
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let r1 = SharePostRecipient(kind: .conversation(directConv))
        XCTAssertEqual(r1.id, "c-\(convId.uuidString)")
        XCTAssertEqual(r1.title, "Alice Smith")
        XCTAssertEqual(r1.subtitle, "@alice")
        XCTAssertEqual(r1.avatarURL, URL(string: "https://example.com/a.jpg"))
        XCTAssertEqual(r1.userIdForAvatar, peerId)
        XCTAssertEqual(r1.target, .conversation(convId))

        let groupConv = Conversation(
            id: convId,
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: "My Group",
            groupAvatarUrl: "https://example.com/g.jpg",
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let r2 = SharePostRecipient(kind: .conversation(groupConv))
        XCTAssertEqual(r2.title, "My Group")
        XCTAssertNil(r2.subtitle)
        XCTAssertEqual(r2.avatarURL, URL(string: "https://example.com/g.jpg"))
        XCTAssertNil(r2.userIdForAvatar)

        let friendUser = UserSummary(
            id: peerId,
            username: "bob",
            displayName: "Bob Jones",
            avatarURL: URL(string: "https://example.com/bob.jpg")
        )
        let r3 = SharePostRecipient(kind: .friend(friendUser))
        XCTAssertEqual(r3.id, "f-\(peerId.uuidString)")
        XCTAssertEqual(r3.title, "Bob Jones")
        XCTAssertEqual(r3.subtitle, "@bob")
        XCTAssertEqual(r3.avatarURL, URL(string: "https://example.com/bob.jpg"))
        XCTAssertEqual(r3.userIdForAvatar, peerId)
        XCTAssertEqual(r3.target, .friend(peerId))
    }

    @MainActor
    func testSharePostViewModelDirectoryLoadingAndSelection() async {
        let myId = UUID()
        let friendId = UUID()
        let convId = UUID()
        let shareUrl = URL(string: "https://splick.app/p/test-post")!

        let conv = Conversation(
            id: convId,
            type: .direct,
            unreadCount: 0,
            peer: ConversationPeer(userId: UUID(), username: "conv_peer", displayName: "Conversation Peer", avatarUrl: nil),
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let friend = UserSummary(id: friendId, username: "friend_bob", displayName: "Bob")
        let repo = MockSharePostMessagingRepository()
        let fetchConvUseCase = FetchConversationsUseCase(repository: repo)
        let sendUseCase = SendMessageUseCase(repository: repo)
        let shareUseCase = SharePostToChatUseCase(repository: repo, sendMessageUseCase: sendUseCase)

        let vm = SharePostViewModel(
            shareURL: shareUrl,
            currentUserId: myId,
            shareUseCase: shareUseCase,
            fetchConversationsUseCase: fetchConvUseCase,
            friendsProvider: { [friend] },
            searchUsersProvider: { query in
                [UserSummary(id: UUID(), username: "\(query)_user", displayName: "Found")]
            },
            languageService: LanguageService(userDefaults: MockUserDefaultsService())
        )

        XCTAssertFalse(vm.canSend)
        await vm.loadDirectoryIfNeeded()

        // Test search query filtering on local recipients
        vm.searchQuery = "Bob"
        XCTAssertFalse(vm.visibleRecipients.isEmpty)

        vm.searchQuery = ""
        XCTAssertEqual(vm.visibleRecipients.count, vm.recipients.count)

        if let first = vm.recipients.first {
            XCTAssertFalse(vm.isSelected(first))
            vm.toggle(first)
            XCTAssertTrue(vm.isSelected(first))
            XCTAssertTrue(vm.canSend)
            vm.toggle(first)
            XCTAssertFalse(vm.isSelected(first))
        }

        // Test remote user toggling
        let remoteUser = UserSummary(id: UUID(), username: "remote_1", displayName: "Remote User")
        XCTAssertFalse(vm.isRemoteUserSelected(remoteUser))
        vm.toggleRemoteUser(remoteUser)
        XCTAssertTrue(vm.isRemoteUserSelected(remoteUser))
        XCTAssertTrue(vm.canSend)

        // Test sending success
        let sendSuccess = await vm.send()
        XCTAssertTrue(sendSuccess)
        XCTAssertNotNil(vm.statusMessage)

        // Test copy link
        vm.copyLinkSucceeded()
        XCTAssertNotNil(vm.statusMessage)
    }

    @MainActor
    func testSharePostViewModelSendFailure() async {
        let shareUrl = URL(string: "https://splick.app/p/test-post")!
        var repo = MockSharePostMessagingRepository()
        repo.sendMessageResult = .failure(URLError(.cannotConnectToHost))
        let fetchConvUseCase = FetchConversationsUseCase(repository: repo)
        let sendUseCase = SendMessageUseCase(repository: repo)
        let shareUseCase = SharePostToChatUseCase(repository: repo, sendMessageUseCase: sendUseCase)

        let vm = SharePostViewModel(
            shareURL: shareUrl,
            currentUserId: UUID(),
            shareUseCase: shareUseCase,
            fetchConversationsUseCase: fetchConvUseCase,
            friendsProvider: { [] },
            searchUsersProvider: { _ in [] },
            languageService: LanguageService(userDefaults: MockUserDefaultsService())
        )

        // Try send without targets
        let sendNoTarget = await vm.send()
        XCTAssertFalse(sendNoTarget)

        // Add target and try send failure
        let user = UserSummary(id: UUID(), username: "bob", displayName: "Bob")
        vm.toggleRemoteUser(user)
        let sendFailed = await vm.send()
        XCTAssertFalse(sendFailed)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testSharePostViewModelEmojiAndGifDraft() async {
        let shareUrl = URL(string: "https://splick.app/p/test-post")!
        let repo = MockSharePostMessagingRepository()
        let vm = SharePostViewModel(
            shareURL: shareUrl,
            currentUserId: UUID(),
            shareUseCase: SharePostToChatUseCase(
                repository: repo,
                sendMessageUseCase: SendMessageUseCase(repository: repo)
            ),
            fetchConversationsUseCase: FetchConversationsUseCase(repository: repo),
            friendsProvider: { [] },
            searchUsersProvider: { _ in [] },
            languageService: LanguageService(userDefaults: MockUserDefaultsService())
        )

        vm.insertEmoji("🎉")
        XCTAssertEqual(vm.messageNote, "🎉")
        vm.insertEmoji(":wave:")
        XCTAssertEqual(vm.messageNote, "🎉 :wave:")

        let gifURL = URL(string: "https://cdn.example/party.gif")!
        vm.attachGif(stickerId: "klipy-1", url: gifURL)
        XCTAssertEqual(vm.gifSubmissions.count, 1)
        XCTAssertEqual(vm.gifSubmissions.first?.remoteURL, gifURL)
        vm.attachGif(stickerId: "klipy-2", url: URL(string: "https://cdn.example/other.gif")!)
        XCTAssertEqual(vm.gifSubmissions.count, 1)
        XCTAssertEqual(vm.gifSubmissions.first?.remoteURL, URL(string: "https://cdn.example/other.gif"))
        vm.removeGif(at: 0)
        XCTAssertTrue(vm.gifSubmissions.isEmpty)
    }
}
