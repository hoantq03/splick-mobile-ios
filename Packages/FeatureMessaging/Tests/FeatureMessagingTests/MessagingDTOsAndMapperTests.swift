import XCTest
import SplickDomain
@testable import FeatureMessaging

final class MessagingDTOsAndMapperTests: XCTestCase {

    func testConversationPeerResponseDTODecoding() throws {
        let userId = UUID()
        let jsonWithOnline = """
        {
            "userId": "\(userId.uuidString)",
            "username": "alice",
            "displayName": "Alice Smith",
            "avatarUrl": "https://example.com/avatar.jpg",
            "online": true,
            "lastSeenAt": "2026-09-20T08:00:00Z"
        }
        """

        let dto1 = try JSONDecoder.apiDecoder.decode(ConversationPeerResponseDTO.self, from: jsonWithOnline.data(using: .utf8)!)
        XCTAssertEqual(dto1.userId, userId)
        XCTAssertEqual(dto1.username, "alice")
        XCTAssertEqual(dto1.displayName, "Alice Smith")
        XCTAssertEqual(dto1.avatarUrl, "https://example.com/avatar.jpg")
        XCTAssertEqual(dto1.online, true)
        XCTAssertNotNil(dto1.lastSeenAt)

        let jsonWithIsOnline = """
        {
            "userId": "\(userId.uuidString)",
            "username": "bob",
            "isOnline": false
        }
        """
        let dto2 = try JSONDecoder.apiDecoder.decode(ConversationPeerResponseDTO.self, from: jsonWithIsOnline.data(using: .utf8)!)
        XCTAssertEqual(dto2.online, false)
        XCTAssertNil(dto2.displayName)
        XCTAssertNil(dto2.avatarUrl)
        XCTAssertNil(dto2.lastSeenAt)

        // Test manual initializer
        let dto3 = ConversationPeerResponseDTO(userId: userId, username: "charlie")
        XCTAssertEqual(dto3.username, "charlie")
        XCTAssertNil(dto3.online)
    }

    func testMessageResponseDTODecodingAndMapper() throws {
        let msgId = UUID()
        let convId = UUID()
        let senderId = UUID()
        let clientMsgId = UUID()
        let reactId = UUID()
        let reactUserId = UUID()
        let replyMsgId = UUID()
        let replySenderId = UUID()

        let json = """
        {
            "id": "\(msgId.uuidString)",
            "conversationId": "\(convId.uuidString)",
            "senderId": "\(senderId.uuidString)",
            "senderDisplayName": "Sender",
            "body": "Test message",
            "clientMessageId": "\(clientMsgId.uuidString)",
            "createdAt": "2026-09-20T08:00:00Z",
            "sequenceNo": 15,
            "editedAt": "2026-09-20T08:05:00Z",
            "recalled": false,
            "reactions": [
                {
                    "id": "\(reactId.uuidString)",
                    "emoji": "🔥",
                    "userId": "\(reactUserId.uuidString)",
                    "createdAt": "2026-09-20T08:01:00Z"
                }
            ],
            "status": "delivered",
            "attachments": [
                {
                    "mediaId": "\(UUID().uuidString)",
                    "url": "https://example.com/pic.jpg",
                    "thumbnailUrl": "https://example.com/pic_thumb.jpg"
                },
                {
                    "url": "invalid url with spaces"
                }
            ],
            "replyPreview": {
                "messageId": "\(replyMsgId.uuidString)",
                "senderId": "\(replySenderId.uuidString)",
                "senderDisplayName": "Replied user",
                "body": "Previous message",
                "hasImageAttachment": true
            },
            "type": "USER"
        }
        """

        let dto = try JSONDecoder.apiDecoder.decode(MessageResponseDTO.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(dto.id, msgId)
        XCTAssertEqual(dto.sequenceNo, 15)
        XCTAssertEqual(dto.recalled, false)
        XCTAssertEqual(dto.status, "delivered")

        let chatMessage = MessagingMapper.toMessage(dto)
        XCTAssertEqual(chatMessage.id, msgId)
        XCTAssertEqual(chatMessage.body, "Test message")
        XCTAssertEqual(chatMessage.deliveryStatus, .delivered)
        XCTAssertEqual(chatMessage.reactions.count, 1)
        XCTAssertEqual(chatMessage.reactions.first?.emoji, "🔥")
        XCTAssertEqual(chatMessage.imageAttachments.count, 2)
        XCTAssertEqual(chatMessage.replyPreview?.messageId, replyMsgId)
        XCTAssertEqual(chatMessage.replyPreview?.hasImageAttachment, true)
        XCTAssertEqual(chatMessage.type, .user)
        XCTAssertNotNil(chatMessage.editedAt)
    }

    func testMessageResponseDTORecalledMapping() {
        let msgId = UUID()
        let convId = UUID()
        let senderId = UUID()
        let clientMsgId = UUID()

        let dto = MessageResponseDTO(
            id: msgId,
            conversationId: convId,
            senderId: senderId,
            body: "Secret info",
            clientMessageId: clientMsgId,
            createdAt: Date(),
            recalled: true,
            reactions: [ReactionResponseDTO(id: UUID(), emoji: "❤️", userId: UUID(), createdAt: Date())],
            status: "read",
            attachments: [MessageAttachmentResponseDTO(mediaId: nil, url: "https://example.com", thumbnailUrl: nil)],
            replyPreview: MessageReplyPreviewResponseDTO(
                messageId: UUID(),
                senderId: UUID(),
                senderDisplayName: nil,
                body: "hello",
                hasImageAttachment: false
            )
        )

        let chatMessage = MessagingMapper.toMessage(dto)
        XCTAssertEqual(chatMessage.body, "")
        XCTAssertTrue(chatMessage.reactions.isEmpty)
        XCTAssertTrue(chatMessage.imageAttachments.isEmpty)
        XCTAssertNil(chatMessage.replyPreview)
        XCTAssertNil(chatMessage.editedAt)
        XCTAssertTrue(chatMessage.recalled)
        XCTAssertEqual(chatMessage.deliveryStatus, .read)
    }

    func testMessageDeliveryStatuses() {
        let baseDto = { (status: String?) in
            MessageResponseDTO(
                id: UUID(),
                conversationId: UUID(),
                senderId: UUID(),
                body: "hi",
                clientMessageId: UUID(),
                createdAt: Date(),
                status: status
            )
        }

        XCTAssertEqual(MessagingMapper.toMessage(baseDto("delivered")).deliveryStatus, .delivered)
        XCTAssertEqual(MessagingMapper.toMessage(baseDto("read")).deliveryStatus, .read)
        XCTAssertEqual(MessagingMapper.toMessage(baseDto("failed")).deliveryStatus, .failed)
        XCTAssertEqual(MessagingMapper.toMessage(baseDto("sending")).deliveryStatus, .sending)
        XCTAssertEqual(MessagingMapper.toMessage(baseDto("sent")).deliveryStatus, .sent)
        XCTAssertEqual(MessagingMapper.toMessage(baseDto("unknown")).deliveryStatus, .sent)
        XCTAssertEqual(MessagingMapper.toMessage(baseDto(nil)).deliveryStatus, .sent)
    }

    func testConversationResponseDTOMapping() {
        let convId = UUID()
        let peerId = UUID()
        let now = Date()

        let peerDto = ConversationPeerResponseDTO(
            userId: peerId,
            username: "peerUser",
            displayName: "Peer",
            avatarUrl: "https://example.com/p.png",
            online: true,
            lastSeenAt: now
        )

        let convDto = ConversationResponseDTO(
            id: convId,
            type: "GROUP",
            unreadCount: 3,
            peer: peerDto,
            groupName: "Test Group",
            groupAvatarUrl: "https://example.com/grp.png",
            memberCount: 5,
            lastMessage: nil,
            createdAt: now,
            updatedAt: now,
            notificationsEnabled: false,
            notificationSound: "chime",
            leftAt: now
        )

        let conversation = MessagingMapper.toConversation(convDto)
        XCTAssertEqual(conversation.id, convId)
        XCTAssertEqual(conversation.type, .group)
        XCTAssertEqual(conversation.unreadCount, 3)
        XCTAssertEqual(conversation.groupName, "Test Group")
        XCTAssertEqual(conversation.memberCount, 5)
        XCTAssertFalse(conversation.notificationsEnabled)
        XCTAssertEqual(conversation.notificationSound, ConversationNotificationSound.`default`.rawValue)
        XCTAssertEqual(conversation.leftAt, now)
        XCTAssertEqual(conversation.peer?.username, "peerUser")
        XCTAssertNil(conversation.mutedUntil)
    }

    func testConversationMapperMutedUntil() {
        let convId = UUID()
        let now = Date()
        let until = now.addingTimeInterval(3600)
        let convDto = ConversationResponseDTO(
            id: convId,
            unreadCount: 0,
            peer: nil,
            createdAt: now,
            updatedAt: now,
            notificationsEnabled: false,
            mutedUntil: until
        )
        let conversation = MessagingMapper.toConversation(convDto)
        XCTAssertEqual(conversation.mutedUntil, until)
        XCTAssertTrue(conversation.isMuted(now: now))
    }

    func testConversationMapperFallbacks() {
        let convId = UUID()
        let now = Date()

        let convDto = ConversationResponseDTO(
            id: convId,
            type: nil,
            unreadCount: 0,
            peer: nil,
            createdAt: now,
            updatedAt: now,
            notificationsEnabled: nil,
            notificationSound: nil,
            leftAt: nil
        )

        let conv = MessagingMapper.toConversation(convDto)
        XCTAssertEqual(conv.type, .direct)
        XCTAssertTrue(conv.notificationsEnabled)
        XCTAssertEqual(conv.notificationSound, ConversationNotificationSound.`default`.rawValue)
        XCTAssertNil(conv.peer)
    }

    func testMessageSearchHitMapping() {
        let msgId = UUID()
        let convId = UUID()
        let now = Date()

        let hitWithPeer = MessageSearchHitResponseDTO(
            messageId: msgId,
            conversationId: convId,
            body: "Found text",
            createdAt: now,
            peer: ConversationPeerResponseDTO(userId: UUID(), username: "bob")
        )

        let domainHit1 = MessagingMapper.toMessageSearchHit(hitWithPeer)
        XCTAssertEqual(domainHit1.messageId, msgId)
        XCTAssertEqual(domainHit1.conversationId, convId)
        XCTAssertEqual(domainHit1.body, "Found text")
        XCTAssertEqual(domainHit1.peer.username, "bob")

        let hitWithoutPeer = MessageSearchHitResponseDTO(
            messageId: msgId,
            conversationId: convId,
            body: "Found text 2",
            createdAt: now,
            peer: nil
        )
        let domainHit2 = MessagingMapper.toMessageSearchHit(hitWithoutPeer)
        XCTAssertEqual(domainHit2.peer.userId, convId)
        XCTAssertEqual(domainHit2.peer.username, "")
    }

    func testGroupChatMemberMapping() {
        let memberAdmin = GroupConversationMemberResponseDTO(
            id: UUID(),
            userId: UUID(),
            username: "adminUser",
            displayName: "Admin",
            avatarUrl: "https://example.com/admin.png",
            role: "ADMIN",
            status: "active"
        )
        let domainAdmin = MessagingMapper.toGroupChatMember(memberAdmin)
        XCTAssertTrue(domainAdmin.isOwner)
        XCTAssertEqual(domainAdmin.username, "adminUser")
        XCTAssertEqual(domainAdmin.avatarURL, URL(string: "https://example.com/admin.png"))

        let memberOwner = GroupConversationMemberResponseDTO(
            id: UUID(),
            userId: UUID(),
            username: "ownerUser",
            displayName: "Owner",
            avatarUrl: nil,
            role: "OWNER",
            status: "active"
        )
        let domainOwner = MessagingMapper.toGroupChatMember(memberOwner)
        XCTAssertTrue(domainOwner.isOwner)

        let memberNormal = GroupConversationMemberResponseDTO(
            id: UUID(),
            userId: UUID(),
            username: "regularUser",
            displayName: "Regular",
            avatarUrl: nil,
            role: "MEMBER",
            status: "active"
        )
        let domainNormal = MessagingMapper.toGroupChatMember(memberNormal)
        XCTAssertFalse(domainNormal.isOwner)
    }

    func testRequestsEncoding() throws {
        let req1 = CreateReactionRequestDTO(emoji: "👍")
        let data1 = try JSONEncoder().encode(req1)
        XCTAssertFalse(data1.isEmpty)

        let req2 = CreateConversationRequestDTO(friendUserId: UUID())
        let data2 = try JSONEncoder().encode(req2)
        XCTAssertFalse(data2.isEmpty)

        let req3 = CreateGroupConversationRequestDTO(
            groupId: UUID(),
            name: "Group",
            avatarUrl: "https://example.com/a.jpg",
            memberUserIds: [UUID()]
        )
        let data3 = try JSONEncoder().encode(req3)
        XCTAssertFalse(data3.isEmpty)

        let req4 = AddGroupMemberRequestDTO(memberUserId: UUID(), shareChatHistory: true)
        let data4 = try JSONEncoder().encode(req4)
        XCTAssertFalse(data4.isEmpty)

        let req5 = RenameGroupRequestDTO(name: "New Name")
        let data5 = try JSONEncoder().encode(req5)
        XCTAssertFalse(data5.isEmpty)

        let req6 = UpdateGroupAvatarRequestDTO(avatarUrl: "https://example.com/b.jpg")
        let data6 = try JSONEncoder().encode(req6)
        XCTAssertFalse(data6.isEmpty)

        let req7 = UpdateConversationNotificationSettingsRequestDTO(
            notificationsEnabled: true,
            notificationSound: "default"
        )
        let data7 = try JSONEncoder().encode(req7)
        XCTAssertFalse(data7.isEmpty)

        let req8 = TransferGroupAdminRequestDTO(newAdminUserId: UUID())
        let data8 = try JSONEncoder().encode(req8)
        XCTAssertFalse(data8.isEmpty)

        let req9 = SendMessageRequestDTO(
            body: "hello",
            clientMessageId: UUID(),
            attachments: [
                SendMessageRequestDTO.MessageAttachmentRequestDTO(
                    mediaId: UUID(),
                    url: "https://example.com",
                    thumbnailUrl: nil
                )
            ],
            replyToMessageId: UUID()
        )
        let data9 = try JSONEncoder().encode(req9)
        XCTAssertFalse(data9.isEmpty)

        let req10 = EditMessageRequestDTO(body: "edited")
        let data10 = try JSONEncoder().encode(req10)
        XCTAssertFalse(data10.isEmpty)

        let req11 = MarkReadRequestDTO(upToMessageId: UUID())
        let data11 = try JSONEncoder().encode(req11)
        XCTAssertFalse(data11.isEmpty)

        let countDto = try JSONDecoder().decode(UnreadMessageCountDTO.self, from: "{\"unreadCount\": 5}".data(using: .utf8)!)
        XCTAssertEqual(countDto.unreadCount, 5)

        let ticketDto = try JSONDecoder().decode(WsTicketResponseDTO.self, from: "{\"ticket\": \"abc123xyz\"}".data(using: .utf8)!)
        XCTAssertEqual(ticketDto.ticket, "abc123xyz")

        let inboxSummaryDto = try JSONDecoder().decode(ConversationInboxSummaryResponseDTO.self, from: "{\"unreadConversationCount\": 7}".data(using: .utf8)!)
        XCTAssertEqual(inboxSummaryDto.unreadConversationCount, 7)
    }
}
