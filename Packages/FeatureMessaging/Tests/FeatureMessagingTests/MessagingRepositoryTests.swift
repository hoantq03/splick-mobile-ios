import XCTest
import Networking
import SplickDomain
@testable import FeatureMessaging

private final class MockAPIClientForMessaging: APIClientProtocol, @unchecked Sendable {
    var lastEndpoint: APIEndpoint?
    var mockResponse: Any?
    var errorToThrow: Error?

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        lastEndpoint = endpoint
        if let error = errorToThrow {
            throw error
        }
        guard let response = mockResponse as? T else {
            fatalError("Mock response type mismatch. Expected \(T.self), got \(String(describing: mockResponse))")
        }
        return response
    }

    func request(_ endpoint: APIEndpoint) async throws {
        lastEndpoint = endpoint
        if let error = errorToThrow {
            throw error
        }
    }

    func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T {
        lastEndpoint = endpoint
        if let error = errorToThrow {
            throw error
        }
        guard let response = mockResponse as? T else {
            fatalError("Mock response type mismatch for upload. Expected \(T.self)")
        }
        return response
    }
}

final class MessagingRepositoryTests: XCTestCase {

    private var apiClient: MockAPIClientForMessaging!
    private var sut: MessagingRepository!

    override func setUp() {
        super.setUp()
        apiClient = MockAPIClientForMessaging()
        sut = MessagingRepository(apiClient: apiClient)
    }

    override func tearDown() {
        apiClient = nil
        sut = nil
        super.tearDown()
    }

    func testFetchConversations() async throws {
        let dummyConvId = UUID()
        let convDto = ConversationResponseDTO(
            id: dummyConvId,
            type: "DIRECT",
            unreadCount: 2,
            peer: ConversationPeerResponseDTO(userId: UUID(), username: "alice"),
            groupName: nil,
            groupAvatarUrl: nil,
            memberCount: nil,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date(),
            notificationsEnabled: true,
            notificationSound: "default",
            leftAt: nil
        )
        let pageDto = PageResponseDTO<ConversationResponseDTO>(items: [convDto], nextCursor: "cur_next", hasMore: true)
        apiClient.mockResponse = pageDto

        let result = try await sut.fetchConversations(query: ConversationInboxQuery(page: 0, limit: 10))

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.id, dummyConvId)
        XCTAssertEqual(result.nextCursor, "cur_next")
        XCTAssertTrue(result.hasMore)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations")
    }

    func testFetchConversationInboxSummary() async throws {
        apiClient.mockResponse = ConversationInboxSummaryResponseDTO(unreadConversationCount: 7)

        let count = try await sut.fetchConversationInboxSummary()
        XCTAssertEqual(count, 7)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/summary")
    }

    func testGetOrCreateConversation() async throws {
        let friendId = UUID()
        let convId = UUID()
        let dto = ConversationResponseDTO(
            id: convId,
            type: "DIRECT",
            unreadCount: 0,
            peer: ConversationPeerResponseDTO(userId: friendId, username: "bob"),
            groupName: nil,
            groupAvatarUrl: nil,
            memberCount: nil,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date(),
            notificationsEnabled: true,
            notificationSound: "default",
            leftAt: nil
        )
        apiClient.mockResponse = dto

        let conv = try await sut.getOrCreateConversation(friendUserId: friendId)
        XCTAssertEqual(conv.id, convId)
        XCTAssertEqual(conv.peer?.userId, friendId)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations")
    }

    func testCreateGroup() async throws {
        let groupId = UUID()
        let memberId = UUID()
        let dto = ConversationResponseDTO(
            id: groupId,
            type: "GROUP",
            unreadCount: 0,
            peer: nil,
            groupName: "Team Chat",
            groupAvatarUrl: "https://team.png",
            memberCount: 2,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date(),
            notificationsEnabled: true,
            notificationSound: "default",
            leftAt: nil
        )
        apiClient.mockResponse = dto

        let conv = try await sut.createGroup(name: "Team Chat", avatarUrl: "https://team.png", memberUserIds: [memberId], groupId: groupId)
        XCTAssertEqual(conv.id, groupId)
        XCTAssertEqual(conv.groupName, "Team Chat")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/groups")
    }

    func testGroupMemberOperations() async throws {
        let groupId = UUID()
        let memberUserId = UUID()

        // addGroupMember
        try await sut.addGroupMember(groupId: groupId, memberUserId: memberUserId, shareChatHistory: true)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/groups/\(groupId)/members")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .post)

        // listGroupMembers
        let memberDTO = GroupConversationMemberResponseDTO(
            id: UUID(),
            userId: memberUserId,
            username: "charlie",
            displayName: "Charlie Brown",
            avatarUrl: nil,
            role: "MEMBER",
            status: "ACTIVE"
        )
        apiClient.mockResponse = [memberDTO]
        let members = try await sut.listGroupMembers(groupId: groupId)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.username, "charlie")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/groups/\(groupId)/members")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .get)

        // removeGroupMember
        try await sut.removeGroupMember(groupId: groupId, memberUserId: memberUserId)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/groups/\(groupId)/members/\(memberUserId)")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .delete)

        // leaveGroup
        try await sut.leaveGroup(groupId: groupId)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/groups/\(groupId)/leave")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .delete)

        // deleteConversation
        try await sut.deleteConversation(conversationId: groupId)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(groupId)")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .delete)
    }

    func testGroupSettingsAndMetadata() async throws {
        let groupId = UUID()
        let convDto = ConversationResponseDTO(
            id: groupId,
            type: "GROUP",
            unreadCount: 0,
            peer: nil,
            groupName: "Renamed Group",
            groupAvatarUrl: "https://new.png",
            memberCount: 3,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date(),
            notificationsEnabled: false,
            notificationSound: "custom",
            leftAt: nil
        )
        apiClient.mockResponse = convDto

        // renameGroup
        let renamed = try await sut.renameGroup(groupId: groupId, name: "Renamed Group")
        XCTAssertEqual(renamed.groupName, "Renamed Group")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/groups/\(groupId)/name")

        // updateGroupAvatar
        let updatedAvatar = try await sut.updateGroupAvatar(groupId: groupId, avatarUrl: "https://new.png")
        XCTAssertEqual(updatedAvatar.groupAvatarUrl, "https://new.png")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/groups/\(groupId)/avatar")

        // updateNotificationSettings
        let updatedSettings = try await sut.updateNotificationSettings(conversationId: groupId, notificationsEnabled: false, notificationSound: "custom")
        XCTAssertFalse(updatedSettings.notificationsEnabled)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(groupId)/notification-settings")

        // transferGroupAdmin
        let newAdmin = UUID()
        try await sut.transferGroupAdmin(groupId: groupId, newAdminUserId: newAdmin)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/groups/\(groupId)/admin")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .put)
    }

    func testFetchMessagesAndSendMessage() async throws {
        let convId = UUID()
        let msgId = UUID()
        let senderId = UUID()

        let msgDTO = MessageResponseDTO(
            id: msgId,
            conversationId: convId,
            senderId: senderId,
            senderDisplayName: "Sender",
            body: "Hello world",
            clientMessageId: UUID(),
            createdAt: Date(),
            sequenceNo: 10,
            editedAt: nil,
            recalled: false,
            reactions: nil,
            status: "SENT",
            attachments: nil,
            replyPreview: nil,
            type: "USER"
        )

        // fetchMessages
        apiClient.mockResponse = PageResponseDTO<MessageResponseDTO>(items: [msgDTO], nextCursor: nil, hasMore: false)
        let messagesPage = try await sut.fetchMessages(conversationId: convId, page: 0, limit: 20, after: nil, before: nil)
        XCTAssertEqual(messagesPage.items.count, 1)
        XCTAssertEqual(messagesPage.items.first?.body, "Hello world")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(convId)/messages")

        // sendMessage
        apiClient.mockResponse = msgDTO
        let sent = try await sut.sendMessage(
            conversationId: convId,
            body: "Hello world",
            clientMessageId: UUID(),
            imageAttachments: [],
            replyToMessageId: nil
        )
        XCTAssertEqual(sent.id, msgId)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(convId)/messages")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .post)
    }

    func testReactionsAndMessageMutations() async throws {
        let convId = UUID()
        let msgId = UUID()
        let reactionId = UUID()
        let currentUserId = UUID()

        // addReaction
        let reactionDTO = ReactionResponseDTO(
            id: reactionId,
            emoji: "🔥",
            userId: currentUserId,
            createdAt: Date()
        )
        apiClient.mockResponse = reactionDTO
        let reaction = try await sut.addReaction(conversationId: convId, messageId: msgId, emoji: "🔥")
        XCTAssertEqual(reaction.id, reactionId)
        XCTAssertEqual(reaction.emoji, "🔥")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(convId)/messages/\(msgId)/reactions")

        // removeReaction
        try await sut.removeReaction(conversationId: convId, messageId: msgId, reactionId: reactionId)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(convId)/messages/\(msgId)/reactions/\(reactionId)")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .delete)

        // editMessage
        let editedMsgDTO = MessageResponseDTO(
            id: msgId,
            conversationId: convId,
            senderId: currentUserId,
            senderDisplayName: "Sender",
            body: "Edited text",
            clientMessageId: UUID(),
            createdAt: Date(),
            sequenceNo: 11,
            editedAt: Date(),
            recalled: false,
            reactions: nil,
            status: "SENT",
            attachments: nil,
            replyPreview: nil,
            type: "USER"
        )
        apiClient.mockResponse = editedMsgDTO
        let edited = try await sut.editMessage(conversationId: convId, messageId: msgId, body: "Edited text")
        XCTAssertEqual(edited.body, "Edited text")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(convId)/messages/\(msgId)")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .patch)

        // recallMessage
        try await sut.recallMessage(conversationId: convId, messageId: msgId)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(convId)/messages/\(msgId)")
        XCTAssertEqual(apiClient.lastEndpoint?.method, .delete)

        // markRead
        try await sut.markRead(conversationId: convId, upToMessageId: msgId)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/conversations/\(convId)/read")

        // unreadCount
        apiClient.mockResponse = UnreadMessageCountDTO(unreadCount: 15)
        let unread = try await sut.unreadCount()
        XCTAssertEqual(unread, 15)
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/unread-count")

        // wsTicket
        apiClient.mockResponse = WsTicketResponseDTO(ticket: "valid-ws-ticket")
        let ticket = try await sut.requestWsTicket()
        XCTAssertEqual(ticket, "valid-ws-ticket")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/ws-ticket")
    }

    func testSearchMessages() async throws {
        let hitDTO = MessageSearchHitResponseDTO(
            messageId: UUID(),
            conversationId: UUID(),
            body: "keyword hit",
            createdAt: Date(),
            peer: ConversationPeerResponseDTO(userId: UUID(), username: "search_peer")
        )
        apiClient.mockResponse = [hitDTO]

        let hits = try await sut.searchMessages(query: "keyword", page: 0, limit: 10, conversationId: nil)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.body, "keyword hit")
        XCTAssertEqual(hits.first?.peer.username, "search_peer")
        XCTAssertEqual(apiClient.lastEndpoint?.path, "/v1/messaging/search")
    }
}
