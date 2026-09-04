import Foundation
import SplickDomain
import FeatureMessaging

public actor FakeMessagingRepository: MessagingRepositoryProtocol {
    private let logger: StateLogger

    private static let aliceId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let bobId   = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let myId    = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!

    private static let sampleConversations: [Conversation] = {
        let conv1Id = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!
        let conv2Id = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000002")!
        let msg1 = ChatMessage(
            id: UUID(),
            conversationId: conv1Id,
            senderId: aliceId,
            body: "Hey! Are you coming tonight? 🎉",
            clientMessageId: UUID(),
            createdAt: Date().addingTimeInterval(-600),
            sequenceNo: 1
        )
        let msg2 = ChatMessage(
            id: UUID(),
            conversationId: conv2Id,
            senderId: bobId,
            body: "Sure, I'll check the menu.",
            clientMessageId: UUID(),
            createdAt: Date().addingTimeInterval(-3600),
            sequenceNo: 1
        )
        return [
            Conversation(
                id: conv1Id,
                unreadCount: 2,
                peer: ConversationPeer(userId: aliceId, username: "alice", displayName: "Alice Nguyen", avatarUrl: nil),
                lastMessage: msg1,
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-600)
            ),
            Conversation(
                id: conv2Id,
                unreadCount: 0,
                peer: ConversationPeer(userId: bobId, username: "bob_tran", displayName: "Bob Trần", avatarUrl: nil),
                lastMessage: msg2,
                createdAt: Date().addingTimeInterval(-172800),
                updatedAt: Date().addingTimeInterval(-3600)
            ),
        ]
    }()

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func fetchConversations(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation> {
        logger.log("fetchConversations page=\(query.page) limit=\(query.limit)")
        try await Task.sleep(for: .milliseconds(300))
        guard query.page == 0 else {
            return MessagingPage(items: [], hasMore: false)
        }

        var items = Self.sampleConversations
        if let type = query.type {
            items = items.filter { $0.type == type }
        }
        if query.unreadOnly {
            items = items.filter { $0.unreadCount > 0 }
        }
        return MessagingPage(items: items, hasMore: false)
    }

    public func fetchConversationInboxSummary() async throws -> Int {
        Self.sampleConversations.filter { $0.unreadCount > 0 }.count
    }

    public func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        logger.log("getOrCreateConversation friendUserId=\(friendUserId)")
        if let existing = Self.sampleConversations.first(where: { $0.peer?.userId == friendUserId }) {
            return existing
        }
        return Conversation(
            id: UUID(),
            unreadCount: 0,
            peer: ConversationPeer(userId: friendUserId, username: "friend", displayName: nil, avatarUrl: nil),
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }


    public func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation {
        logger.log("createGroup name=\(name) members=\(memberUserIds.count)")
        return Conversation(
            id: groupId ?? UUID(),
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: name,
            groupAvatarUrl: avatarUrl,
            memberCount: memberUserIds.count + 1,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    public func addGroupMember(groupId: UUID, memberUserId: UUID, shareChatHistory: Bool) async throws {
        logger.log("addGroupMember groupId=\(groupId) memberUserId=\(memberUserId) shareChatHistory=\(shareChatHistory)")
    }

    public func listGroupMembers(groupId: UUID) async throws -> [GroupChatMember] {
        logger.log("listGroupMembers groupId=\(groupId)")
        return []
    }

    public func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws {
        logger.log("removeGroupMember groupId=\(groupId) memberUserId=\(memberUserId)")
    }

    public func leaveGroup(groupId: UUID) async throws {
        logger.log("leaveGroup groupId=\(groupId)")
    }

    public func deleteConversation(conversationId: UUID) async throws {
        logger.log("deleteConversation conversationId=\(conversationId)")
    }

    public func updateNotificationSettings(
        conversationId: UUID,
        notificationsEnabled: Bool,
        notificationSound: String
    ) async throws -> Conversation {
        logger.log(
            "updateNotificationSettings conversationId=\(conversationId) enabled=\(notificationsEnabled) sound=\(notificationSound)"
        )
        return Conversation(
            id: conversationId,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date(),
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound
        )
    }

    public func renameGroup(groupId: UUID, name: String) async throws -> Conversation {
        logger.log("renameGroup groupId=\(groupId) name=\(name)")
        return Conversation(
            id: groupId,
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: name,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    public func updateGroupAvatar(groupId: UUID, avatarUrl: String) async throws -> Conversation {
        logger.log("updateGroupAvatar groupId=\(groupId)")
        return Conversation(
            id: groupId,
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupAvatarUrl: avatarUrl,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    public func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws {
        logger.log("transferGroupAdmin groupId=\(groupId) newAdminUserId=\(newAdminUserId)")
    }

    public func fetchMessages(
        conversationId: UUID,
        page: Int,
        limit: Int,
        after: Int64?,
        before: Int64?
    ) async throws -> MessagingPage<ChatMessage> {
        logger.log("fetchMessages conversationId=\(conversationId) after=\(after as Any) before=\(before as Any)")
        guard page == 0,
              after == nil,
              before == nil,
              let conv = Self.sampleConversations.first(where: { $0.id == conversationId }),
              let peer = conv.peer else {
            return MessagingPage(items: [], hasMore: false)
        }
        let items = [
            ChatMessage(
                id: UUID(),
                conversationId: conversationId,
                senderId: Self.myId,
                body: "Hi! What's up?",
                clientMessageId: UUID(),
                createdAt: Date().addingTimeInterval(-900),
                sequenceNo: 1
            ),
            ChatMessage(
                id: UUID(),
                conversationId: conversationId,
                senderId: peer.userId,
                senderDisplayName: peer.displayTitle,
                body: conv.lastMessage?.body ?? "Hello!",
                clientMessageId: UUID(),
                createdAt: Date().addingTimeInterval(-600),
                sequenceNo: 2
            ),
        ]
        return MessagingPage(items: items, hasMore: false)
    }

    public func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment],
        replyToMessageId: UUID? = nil
    ) async throws -> ChatMessage {
        logger.log("sendMessage conversationId=\(conversationId) body=\(body) attachments=\(imageAttachments.count)")
        return ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: Self.myId,
            senderDisplayName: "You",
            body: body,
            clientMessageId: clientMessageId,
            createdAt: Date(),
            sequenceNo: 3,
            imageAttachments: imageAttachments
        )
    }

    public func markRead(conversationId: UUID, upToMessageId: UUID) async throws {
        logger.log("markRead conversationId=\(conversationId)")
    }

    public func unreadCount() async throws -> Int {
        return Self.sampleConversations.reduce(0) { $0 + $1.unreadCount }
    }

    public func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        logger.log("addReaction conversationId=\(conversationId) messageId=\(messageId) emoji=\(emoji)")
        return Reaction(id: UUID(), emoji: emoji, userId: Self.myId, createdAt: Date())
    }

    public func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws {
        logger.log("removeReaction conversationId=\(conversationId) messageId=\(messageId) reactionId=\(reactionId)")
    }

    public func searchMessages(
        query: String,
        page: Int,
        limit: Int,
        conversationId: UUID?
    ) async throws -> [MessageSearchHit] {
        logger.log("searchMessages query=\(query)")
        guard page == 0,
              let conv = Self.sampleConversations.first(where: { conversationId == nil || $0.id == conversationId }),
              let peer = conv.peer,
              let lastMessage = conv.lastMessage else { return [] }

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty,
              lastMessage.body.lowercased().contains(normalized) else { return [] }

        return [
            MessageSearchHit(
                messageId: lastMessage.id,
                conversationId: conv.id,
                body: lastMessage.body,
                createdAt: lastMessage.createdAt,
                peer: peer
            )
        ]
    }

    public func editMessage(conversationId: UUID, messageId: UUID, body: String) async throws -> ChatMessage {
        ChatMessage(
            id: messageId,
            conversationId: conversationId,
            senderId: UUID(),
            body: body,
            clientMessageId: UUID(),
            createdAt: Date(),
            editedAt: Date()
        )
    }

    public func recallMessage(conversationId: UUID, messageId: UUID) async throws {}

    public func requestWsTicket() async throws -> String {
        "fake-ws-ticket"
    }
}
