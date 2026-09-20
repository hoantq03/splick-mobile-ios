import XCTest
import Networking
import SplickDomain
@testable import FeatureMessaging

final class MessagingEndpointTests: XCTestCase {

    func testPaths() {
        let conversationId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let messageId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let groupId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let memberUserId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let reactionId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let friendUserId = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

        XCTAssertEqual(MessagingEndpoint.listConversations(ConversationInboxQuery(page: 1, limit: 20)).path, "/v1/messaging/conversations")
        XCTAssertEqual(MessagingEndpoint.conversationInboxSummary.path, "/v1/messaging/conversations/summary")
        XCTAssertEqual(MessagingEndpoint.getOrCreateConversation(friendUserId: friendUserId).path, "/v1/messaging/conversations")
        XCTAssertEqual(MessagingEndpoint.createGroup(.init(groupId: groupId, name: "G", avatarUrl: nil, memberUserIds: [])).path, "/v1/messaging/groups")
        XCTAssertEqual(MessagingEndpoint.addGroupMember(groupId: groupId, .init(memberUserId: memberUserId, shareChatHistory: true)).path, "/v1/messaging/groups/\(groupId)/members")
        XCTAssertEqual(MessagingEndpoint.listGroupMembers(groupId: groupId).path, "/v1/messaging/groups/\(groupId)/members")
        XCTAssertEqual(MessagingEndpoint.removeGroupMember(groupId: groupId, memberUserId: memberUserId).path, "/v1/messaging/groups/\(groupId)/members/\(memberUserId)")
        XCTAssertEqual(MessagingEndpoint.leaveGroup(groupId: groupId).path, "/v1/messaging/groups/\(groupId)/leave")
        XCTAssertEqual(MessagingEndpoint.deleteConversation(conversationId: conversationId).path, "/v1/messaging/conversations/\(conversationId)")
        XCTAssertEqual(MessagingEndpoint.renameGroup(groupId: groupId, .init(name: "New")).path, "/v1/messaging/groups/\(groupId)/name")
        XCTAssertEqual(MessagingEndpoint.updateGroupAvatar(groupId: groupId, .init(avatarUrl: "https://avatar")).path, "/v1/messaging/groups/\(groupId)/avatar")
        XCTAssertEqual(MessagingEndpoint.updateNotificationSettings(conversationId: conversationId, .init(notificationsEnabled: true, notificationSound: "default")).path, "/v1/messaging/conversations/\(conversationId)/notification-settings")
        XCTAssertEqual(MessagingEndpoint.transferGroupAdmin(groupId: groupId, .init(newAdminUserId: memberUserId)).path, "/v1/messaging/groups/\(groupId)/admin")
        XCTAssertEqual(MessagingEndpoint.listMessages(conversationId: conversationId, page: 0, limit: 20, after: nil, before: nil).path, "/v1/messaging/conversations/\(conversationId)/messages")
        XCTAssertEqual(MessagingEndpoint.sendMessage(conversationId: conversationId, body: "hi", clientMessageId: UUID(), attachments: [], replyToMessageId: nil).path, "/v1/messaging/conversations/\(conversationId)/messages")
        XCTAssertEqual(MessagingEndpoint.editMessage(conversationId: conversationId, messageId: messageId, .init(body: "edited")).path, "/v1/messaging/conversations/\(conversationId)/messages/\(messageId)")
        XCTAssertEqual(MessagingEndpoint.recallMessage(conversationId: conversationId, messageId: messageId).path, "/v1/messaging/conversations/\(conversationId)/messages/\(messageId)")
        XCTAssertEqual(MessagingEndpoint.markRead(conversationId: conversationId, upToMessageId: messageId).path, "/v1/messaging/conversations/\(conversationId)/read")
        XCTAssertEqual(MessagingEndpoint.unreadCount.path, "/v1/messaging/unread-count")
        XCTAssertEqual(MessagingEndpoint.searchMessages(q: "splick", page: 0, limit: 10, conversationId: conversationId).path, "/v1/messaging/search")
        XCTAssertEqual(MessagingEndpoint.addReaction(conversationId: conversationId, messageId: messageId, .init(emoji: "❤️")).path, "/v1/messaging/conversations/\(conversationId)/messages/\(messageId)/reactions")
        XCTAssertEqual(MessagingEndpoint.removeReaction(conversationId: conversationId, messageId: messageId, reactionId: reactionId).path, "/v1/messaging/conversations/\(conversationId)/messages/\(messageId)/reactions/\(reactionId)")
        XCTAssertEqual(MessagingEndpoint.wsTicket.path, "/v1/messaging/ws-ticket")
    }

    func testHTTPMethods() {
        let dummyId = UUID()

        // GET
        XCTAssertEqual(MessagingEndpoint.listConversations(.init()).method, .get)
        XCTAssertEqual(MessagingEndpoint.conversationInboxSummary.method, .get)
        XCTAssertEqual(MessagingEndpoint.listGroupMembers(groupId: dummyId).method, .get)
        XCTAssertEqual(MessagingEndpoint.listMessages(conversationId: dummyId, page: 0, limit: 20, after: nil, before: nil).method, .get)
        XCTAssertEqual(MessagingEndpoint.unreadCount.method, .get)
        XCTAssertEqual(MessagingEndpoint.searchMessages(q: "", page: 0, limit: 10, conversationId: nil).method, .get)

        // POST
        XCTAssertEqual(MessagingEndpoint.getOrCreateConversation(friendUserId: dummyId).method, .post)
        XCTAssertEqual(MessagingEndpoint.createGroup(.init(groupId: nil, name: "", avatarUrl: nil, memberUserIds: [])).method, .post)
        XCTAssertEqual(MessagingEndpoint.addGroupMember(groupId: dummyId, .init(memberUserId: dummyId, shareChatHistory: false)).method, .post)
        XCTAssertEqual(MessagingEndpoint.sendMessage(conversationId: dummyId, body: "", clientMessageId: dummyId, attachments: [], replyToMessageId: nil).method, .post)
        XCTAssertEqual(MessagingEndpoint.markRead(conversationId: dummyId, upToMessageId: dummyId).method, .post)
        XCTAssertEqual(MessagingEndpoint.addReaction(conversationId: dummyId, messageId: dummyId, .init(emoji: "")).method, .post)
        XCTAssertEqual(MessagingEndpoint.wsTicket.method, .post)

        // DELETE
        XCTAssertEqual(MessagingEndpoint.removeGroupMember(groupId: dummyId, memberUserId: dummyId).method, .delete)
        XCTAssertEqual(MessagingEndpoint.leaveGroup(groupId: dummyId).method, .delete)
        XCTAssertEqual(MessagingEndpoint.deleteConversation(conversationId: dummyId).method, .delete)
        XCTAssertEqual(MessagingEndpoint.recallMessage(conversationId: dummyId, messageId: dummyId).method, .delete)
        XCTAssertEqual(MessagingEndpoint.removeReaction(conversationId: dummyId, messageId: dummyId, reactionId: dummyId).method, .delete)

        // PATCH
        XCTAssertEqual(MessagingEndpoint.renameGroup(groupId: dummyId, .init(name: "")).method, .patch)
        XCTAssertEqual(MessagingEndpoint.updateGroupAvatar(groupId: dummyId, .init(avatarUrl: "")).method, .patch)
        XCTAssertEqual(MessagingEndpoint.updateNotificationSettings(conversationId: dummyId, .init(notificationsEnabled: true, notificationSound: "")).method, .patch)
        XCTAssertEqual(MessagingEndpoint.editMessage(conversationId: dummyId, messageId: dummyId, .init(body: "")).method, .patch)

        // PUT
        XCTAssertEqual(MessagingEndpoint.transferGroupAdmin(groupId: dummyId, .init(newAdminUserId: dummyId)).method, .put)
    }

    func testQueryItems() {
        let dummyId = UUID()

        // List conversations with all filters
        let qAll = ConversationInboxQuery(page: 2, limit: 30, type: .group, unreadOnly: true)
        let itemsAll = MessagingEndpoint.listConversations(qAll).queryItems
        XCTAssertNotNil(itemsAll)
        XCTAssertTrue(itemsAll!.contains(where: { $0.name == "type" && $0.value == "GROUP" }))
        XCTAssertTrue(itemsAll!.contains(where: { $0.name == "unreadOnly" && $0.value == "true" }))
        XCTAssertTrue(itemsAll!.contains(where: { $0.name == "page" && $0.value == "2" }))
        XCTAssertTrue(itemsAll!.contains(where: { $0.name == "limit" && $0.value == "30" }))

        // List messages with after and before
        let msgItems = MessagingEndpoint.listMessages(conversationId: dummyId, page: 1, limit: 15, after: 100, before: 200).queryItems
        XCTAssertNotNil(msgItems)
        XCTAssertTrue(msgItems!.contains(where: { $0.name == "page" && $0.value == "1" }))
        XCTAssertTrue(msgItems!.contains(where: { $0.name == "limit" && $0.value == "15" }))
        XCTAssertTrue(msgItems!.contains(where: { $0.name == "after" && $0.value == "100" }))
        XCTAssertTrue(msgItems!.contains(where: { $0.name == "before" && $0.value == "200" }))

        // Search messages with conversationId
        let searchItems = MessagingEndpoint.searchMessages(q: "findMe", page: 0, limit: 10, conversationId: dummyId).queryItems
        XCTAssertNotNil(searchItems)
        XCTAssertTrue(searchItems!.contains(where: { $0.name == "q" && $0.value == "findMe" }))
        XCTAssertTrue(searchItems!.contains(where: { $0.name == "conversationId" && $0.value == dummyId.uuidString.lowercased() }))

        // Search messages without conversationId
        let searchGlobal = MessagingEndpoint.searchMessages(q: "test", page: 0, limit: 5, conversationId: nil).queryItems
        XCTAssertFalse(searchGlobal!.contains(where: { $0.name == "conversationId" }))

        // Endpoints with no query items
        XCTAssertNil(MessagingEndpoint.unreadCount.queryItems)
    }

    func testBodyEncoding() {
        let dummyId = UUID()
        let friendId = UUID()

        XCTAssertNotNil(MessagingEndpoint.getOrCreateConversation(friendUserId: friendId).body)
        XCTAssertNotNil(MessagingEndpoint.createGroup(.init(groupId: nil, name: "Name", avatarUrl: nil, memberUserIds: [dummyId])).body)
        XCTAssertNotNil(MessagingEndpoint.addGroupMember(groupId: dummyId, .init(memberUserId: friendId, shareChatHistory: false)).body)
        XCTAssertNotNil(MessagingEndpoint.renameGroup(groupId: dummyId, .init(name: "New")).body)
        XCTAssertNotNil(MessagingEndpoint.updateGroupAvatar(groupId: dummyId, .init(avatarUrl: "url")).body)
        XCTAssertNotNil(MessagingEndpoint.updateNotificationSettings(conversationId: dummyId, .init(notificationsEnabled: false, notificationSound: "silent")).body)
        XCTAssertNotNil(MessagingEndpoint.transferGroupAdmin(groupId: dummyId, .init(newAdminUserId: friendId)).body)

        // Send message with attachments
        let attachment = SendMessageRequestDTO.MessageAttachmentRequestDTO(mediaId: nil, url: "https://img", thumbnailUrl: nil)
        let sendEndpoint = MessagingEndpoint.sendMessage(
            conversationId: dummyId,
            body: "text",
            clientMessageId: dummyId,
            attachments: [attachment],
            replyToMessageId: dummyId
        )
        XCTAssertNotNil(sendEndpoint.body)

        XCTAssertNotNil(MessagingEndpoint.editMessage(conversationId: dummyId, messageId: dummyId, .init(body: "edit")).body)
        XCTAssertNotNil(MessagingEndpoint.markRead(conversationId: dummyId, upToMessageId: dummyId).body)
        XCTAssertNotNil(MessagingEndpoint.addReaction(conversationId: dummyId, messageId: dummyId, .init(emoji: "👍")).body)

        // Body is nil for GET/DELETE without body
        XCTAssertNil(MessagingEndpoint.unreadCount.body)
        XCTAssertNil(MessagingEndpoint.leaveGroup(groupId: dummyId).body)
    }
}
