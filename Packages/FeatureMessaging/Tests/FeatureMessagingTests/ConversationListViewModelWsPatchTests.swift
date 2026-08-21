import XCTest
@testable import FeatureMessaging
import Common
import Localization
import SplickDomain
import Storage

@MainActor
final class ConversationListViewModelWsPatchTests: XCTestCase {

    private let currentUserId = UUID(uuidString: "cccccccc-0000-0000-0000-000000000001")!
    private let peerUserId = UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000001")!

    private func makeViewModel(
        repository: PeekMessagingRepositoryStub = PeekMessagingRepositoryStub(),
        wsClient: MessagingWebSocketClient
    ) -> ConversationListViewModel {
        let languageService = LanguageService(userDefaults: UserDefaultsService())
        languageService.setLocale(.vi, persist: false)
        let vm = ConversationListViewModel(
            fetchConversationsUseCase: FetchConversationsUseCase(repository: repository),
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repository),
            searchProvider: PeekSearchProviderStub(),
            repository: repository,
            wsClient: wsClient,
            languageService: languageService
        )
        vm.currentUserId = currentUserId
        return vm
    }

    func test_wsNewMessage_patchesExistingConversationWithoutFullReload() async {
        let conversationId = UUID()
        let otherId = UUID()
        let existing = Conversation(
            id: conversationId,
            unreadCount: 0,
            peer: ConversationPeer(
                userId: peerUserId,
                username: "peer",
                displayName: "Peer",
                avatarUrl: nil
            ),
            lastMessage: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let other = Conversation(
            id: otherId,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: Date(timeIntervalSince1970: 2),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let wsClient = MessagingWebSocketClient(
            ticketProvider: { "ticket" },
            deviceIdProvider: { "device" }
        )
        // Repository returns empty — if WS triggered refresh, list would be wiped.
        let viewModel = makeViewModel(wsClient: wsClient)
        viewModel.applyStartupConversations([other, existing])
        XCTAssertEqual(viewModel.conversations.map(\.id), [otherId, conversationId])

        let incoming = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: peerUserId,
            body: "Hello live",
            clientMessageId: UUID(),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        wsClient.eventSubject.send(.newMessage(conversationId: conversationId, message: incoming))
        await Task.yield()

        XCTAssertEqual(viewModel.conversations.first?.id, conversationId)
        XCTAssertEqual(viewModel.conversations.first?.lastMessage?.body, "Hello live")
        XCTAssertEqual(viewModel.conversations.first?.unreadCount, 1)
        XCTAssertEqual(viewModel.unreadConversationCount, 1)
        XCTAssertEqual(viewModel.conversations.count, 2, "Must not wipe list via full refresh")
    }

    func test_wsNewMessage_fromPeer_acknowledgesDelivery() async {
        MessageDeliveryAckService.shared.resetAckTrackingForTests()
        let conversationId = UUID()
        let messageId = UUID()
        let existing = Conversation(
            id: conversationId,
            unreadCount: 0,
            peer: ConversationPeer(
                userId: peerUserId,
                username: "peer",
                displayName: "Peer",
                avatarUrl: nil
            ),
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now
        )
        let wsClient = MessagingWebSocketClient(
            ticketProvider: { "ticket" },
            deviceIdProvider: { "device" }
        )
        MessageDeliveryAckService.shared.configure(wsClient: wsClient)
        let viewModel = makeViewModel(wsClient: wsClient)
        viewModel.applyStartupConversations([existing])

        let incoming = ChatMessage(
            id: messageId,
            conversationId: conversationId,
            senderId: peerUserId,
            body: "Delivered to device",
            clientMessageId: UUID(),
            createdAt: .now
        )
        viewModel.handleIncomingWsMessageForTesting(conversationId: conversationId, message: incoming)

        XCTAssertEqual(MessageDeliveryAckService.shared.lastAcknowledgedConversationId, conversationId)
        XCTAssertEqual(MessageDeliveryAckService.shared.lastAcknowledgedMessageId, messageId)
    }

    func test_wsNewMessage_fromSelf_doesNotBumpUnread() async {
        let conversationId = UUID()
        let existing = Conversation(
            id: conversationId,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now
        )
        let wsClient = MessagingWebSocketClient(
            ticketProvider: { "ticket" },
            deviceIdProvider: { "device" }
        )
        let viewModel = makeViewModel(wsClient: wsClient)
        viewModel.applyStartupConversations([existing])

        let outgoing = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: currentUserId,
            body: "Sent by me",
            clientMessageId: UUID(),
            createdAt: .now
        )
        wsClient.eventSubject.send(.newMessage(conversationId: conversationId, message: outgoing))
        await Task.yield()

        XCTAssertEqual(viewModel.conversations.first?.unreadCount, 0)
        XCTAssertEqual(viewModel.unreadConversationCount, 0)
        XCTAssertEqual(viewModel.conversations.first?.lastMessage?.body, "Sent by me")
    }
}

// Reuse peek stubs from the same test module.
private struct PeekSearchProviderStub: MessagingSearchProviding {
    func search(query: String) async throws -> [MessagingSearchResult] { [] }
}

private actor PeekMessagingRepositoryStub: MessagingRepositoryProtocol {
    func fetchConversations(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation> {
        MessagingPage(items: [], hasMore: false)
    }
    func fetchConversationInboxSummary() async throws -> Int { 0 }
    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        Conversation(id: UUID(), unreadCount: 0, peer: nil, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }
    func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation {
        Conversation(id: groupId ?? UUID(), type: .group, unreadCount: 0, peer: nil, groupName: name, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }
    func addGroupMember(groupId: UUID, memberUserId: UUID) async throws {}
    func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws {}
    func leaveGroup(groupId: UUID) async throws {}
    func deleteConversation(conversationId: UUID) async throws {}
    func updateNotificationSettings(
        conversationId: UUID,
        notificationsEnabled: Bool,
        notificationSound: String
    ) async throws -> Conversation {
        Conversation(
            id: conversationId,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound
        )
    }
    func renameGroup(groupId: UUID, name: String) async throws -> Conversation {
        Conversation(id: groupId, unreadCount: 0, peer: nil, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }
    func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws {}
    func fetchMessages(
        conversationId: UUID,
        page: Int,
        limit: Int,
        after: Int64?,
        before: Int64?
    ) async throws -> MessagingPage<ChatMessage> {
        MessagingPage(items: [], hasMore: false)
    }
    func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment],
        replyToMessageId: UUID?
    ) async throws -> ChatMessage {
        ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: UUID(),
            body: body,
            clientMessageId: clientMessageId,
            createdAt: .now,
            imageAttachments: imageAttachments
        )
    }
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws {}
    func unreadCount() async throws -> Int { 0 }
    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: .now)
    }
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws {}
    func searchMessages(query: String, page: Int, limit: Int, conversationId: UUID?) async throws -> [MessageSearchHit] { [] }
    func requestWsTicket() async throws -> String { "ws-patch-ticket" }
}
