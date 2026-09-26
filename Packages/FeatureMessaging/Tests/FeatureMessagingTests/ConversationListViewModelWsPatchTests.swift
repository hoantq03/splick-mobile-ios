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

    func test_upsertConversation_updatesGroupNameInPlace() async {
        let conversationId = UUID()
        let existing = Conversation(
            id: conversationId,
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: "Old name",
            lastMessage: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let wsClient = MessagingWebSocketClient(
            ticketProvider: { "ticket" },
            deviceIdProvider: { "device" }
        )
        let viewModel = makeViewModel(wsClient: wsClient)
        viewModel.applyStartupConversations([existing])

        viewModel.upsertConversation(existing.updating(groupName: "New name"))

        XCTAssertEqual(viewModel.conversations.first?.groupName, "New name")
        XCTAssertEqual(viewModel.conversations.first?.displayTitle, "New name")
        XCTAssertEqual(viewModel.conversations.count, 1)
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

    func test_wsNewMessage_whileThreadOpen_doesNotKeepConversationUnread() {
        let conversationId = UUID()
        let existing = Conversation(
            id: conversationId,
            unreadCount: 1,
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
        let viewModel = makeViewModel(wsClient: wsClient)
        viewModel.applyStartupConversations([existing])
        viewModel.setUnreadConversationCountForTests(1)
        viewModel.setActiveConversation(conversationId)
        XCTAssertEqual(viewModel.conversations.first?.unreadCount, 0)

        let incoming = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: peerUserId,
            body: "Still in thread",
            clientMessageId: UUID(),
            createdAt: .now
        )
        viewModel.handleIncomingWsMessageForTesting(conversationId: conversationId, message: incoming)

        XCTAssertEqual(viewModel.conversations.first?.unreadCount, 0)
        XCTAssertEqual(viewModel.conversations.first?.lastMessage?.body, "Still in thread")
        XCTAssertEqual(viewModel.unreadConversationCount, 0)
    }

    func test_markConversationAsRead_dropsRowFromUnreadFilterAndClearsBadge() {
        let conversationId = UUID()
        let unread = Conversation(
            id: conversationId,
            unreadCount: 3,
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
        viewModel.applyStartupConversations([unread])
        viewModel.setUnreadConversationCountForTests(1)
        viewModel.setActiveFilterForTests(.unread)

        viewModel.markConversationAsRead(conversationId: conversationId)

        XCTAssertTrue(viewModel.conversations.isEmpty)
        XCTAssertEqual(viewModel.unreadConversationCount, 0)
    }

    func test_markConversationAsRead_keepsRowOnAllFilterWithZeroUnread() {
        let conversationId = UUID()
        let unread = Conversation(
            id: conversationId,
            type: .group,
            unreadCount: 1,
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
        viewModel.applyStartupConversations([unread])
        viewModel.setUnreadConversationCountForTests(1)

        viewModel.markConversationAsRead(conversationId: conversationId)

        XCTAssertEqual(viewModel.conversations.count, 1)
        XCTAssertEqual(viewModel.conversations.first?.unreadCount, 0)
        XCTAssertEqual(viewModel.unreadConversationCount, 0)
    }

    func test_incomingMessage_onUsersFilter_removesGroupConversation() {
        let conversationId = UUID()
        let group = Conversation(
            id: conversationId,
            type: .group,
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
        viewModel.applyStartupConversations([group])
        viewModel.setActiveFilterForTests(.users)

        let incoming = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: peerUserId,
            body: "Should not stay on people filter",
            clientMessageId: UUID(),
            createdAt: .now
        )
        viewModel.handleIncomingWsMessageForTesting(conversationId: conversationId, message: incoming)

        XCTAssertTrue(viewModel.conversations.isEmpty)
    }

    func test_typingEvent_tracksPeerForConversationPreview() async {
        let conversationId = UUID()
        let wsClient = MessagingWebSocketClient(
            ticketProvider: { "ticket" },
            deviceIdProvider: { "device" }
        )
        let viewModel = makeViewModel(wsClient: wsClient)

        viewModel.handleIncomingTypingForTesting(
            conversationId: conversationId,
            userId: peerUserId,
            isTyping: true
        )
        XCTAssertEqual(viewModel.typingUserIdsByConversation[conversationId], [peerUserId])

        viewModel.handleIncomingTypingForTesting(
            conversationId: conversationId,
            userId: currentUserId,
            isTyping: true
        )
        XCTAssertEqual(viewModel.typingUserIdsByConversation[conversationId], [peerUserId])

        viewModel.handleIncomingTypingForTesting(
            conversationId: conversationId,
            userId: peerUserId,
            isTyping: false
        )
        XCTAssertNil(viewModel.typingUserIdsByConversation[conversationId])
    }
}
