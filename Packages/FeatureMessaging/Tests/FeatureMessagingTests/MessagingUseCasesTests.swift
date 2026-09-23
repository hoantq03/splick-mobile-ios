import XCTest
import SplickDomain
@testable import FeatureMessaging

private actor MockMessagingRepositoryForUseCases: MessagingRepositoryProtocol {
    var createdGroupArgs: (name: String, avatarUrl: String?, memberUserIds: [UUID], groupId: UUID?)?
    var addedReactions: [(conversationId: UUID, messageId: UUID, emoji: String)] = []
    var conversationsByFriend: [UUID: Conversation] = [:]
    var sentMessages: [(conversationId: UUID, body: String, clientId: UUID, attachments: [MessageImageAttachment])] = []

    func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation {
        createdGroupArgs = (name, avatarUrl, memberUserIds, groupId)
        return Conversation(
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

    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        addedReactions.append((conversationId, messageId, emoji))
        return Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: Date())
    }

    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        if let existing = conversationsByFriend[friendUserId] {
            return existing
        }
        let created = Conversation(
            id: UUID(),
            unreadCount: 0,
            peer: ConversationPeer(userId: friendUserId, username: "friend_\(friendUserId.uuidString.prefix(4))", displayName: nil, avatarUrl: nil),
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        conversationsByFriend[friendUserId] = created
        return created
    }

    func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment],
        replyToMessageId: UUID?
    ) async throws -> ChatMessage {
        sentMessages.append((conversationId, body, clientMessageId, imageAttachments))
        return ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: UUID(),
            body: body,
            clientMessageId: clientMessageId,
            createdAt: Date(),
            sequenceNo: 1,
            imageAttachments: imageAttachments
        )
    }

    func fetchConversations(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation> { MessagingPage(items: [], hasMore: false) }
    func fetchConversationInboxSummary() async throws -> Int { 0 }
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
        Conversation(id: conversationId, unreadCount: 0, peer: nil, lastMessage: nil, createdAt: Date(), updatedAt: Date())
    }
    func renameGroup(groupId: UUID, name: String) async throws -> Conversation {
        Conversation(id: groupId, unreadCount: 0, peer: nil, lastMessage: nil, createdAt: Date(), updatedAt: Date())
    }
    func updateGroupAvatar(groupId: UUID, avatarUrl: String) async throws -> Conversation {
        Conversation(id: groupId, unreadCount: 0, peer: nil, lastMessage: nil, createdAt: Date(), updatedAt: Date())
    }
    func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws {}
    func fetchMessages(conversationId: UUID, page: Int, limit: Int, after: Int64?, before: Int64?) async throws -> MessagingPage<ChatMessage> {
        MessagingPage(items: [], hasMore: false)
    }
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws {}
    func unreadCount() async throws -> Int { 0 }
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws {}
    func searchMessages(query: String, page: Int, limit: Int, conversationId: UUID?) async throws -> [MessageSearchHit] { [] }
    func editMessage(conversationId: UUID, messageId: UUID, body: String) async throws -> ChatMessage {
        ChatMessage(id: messageId, conversationId: conversationId, senderId: UUID(), body: body, clientMessageId: UUID(), createdAt: Date())
    }
    func recallMessage(conversationId: UUID, messageId: UUID) async throws {}
    func requestWsTicket() async throws -> String { "ticket" }
}

final class MessagingUseCasesTests: XCTestCase {

    func testCreateGroupConversationUseCase() async throws {
        let repo = MockMessagingRepositoryForUseCases()
        let sut = CreateGroupConversationUseCase(repository: repo)

        let member1 = UUID()
        let member2 = UUID()
        let specifiedId = UUID()
        let conv = try await sut.execute(
            name: "Awesome Group",
            avatarUrl: "https://avatar.png",
            memberUserIds: [member1, member2],
            groupId: specifiedId
        )

        XCTAssertEqual(conv.id, specifiedId)
        XCTAssertEqual(conv.groupName, "Awesome Group")

        let args = await repo.createdGroupArgs
        XCTAssertEqual(args?.name, "Awesome Group")
        XCTAssertEqual(args?.avatarUrl, "https://avatar.png")
        XCTAssertEqual(args?.memberUserIds, [member1, member2])
        XCTAssertEqual(args?.groupId, specifiedId)
    }

    func testReactToMessageUseCase() async throws {
        let repo = MockMessagingRepositoryForUseCases()
        let sut = ReactToMessageUseCase(repository: repo)

        let convId = UUID()
        let msgId = UUID()
        let reaction = try await sut.execute(conversationId: convId, messageId: msgId, emoji: "🚀")

        XCTAssertEqual(reaction.emoji, "🚀")
        let added = await repo.addedReactions
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.conversationId, convId)
        XCTAssertEqual(added.first?.messageId, msgId)
        XCTAssertEqual(added.first?.emoji, "🚀")
    }

    func testSharePostToChatUseCase_targetsDeduplicationAndMixedTargets() async {
        let repo = MockMessagingRepositoryForUseCases()
        let sendUseCase = SendMessageUseCase(repository: repo)
        let sut = SharePostToChatUseCase(repository: repo, sendMessageUseCase: sendUseCase)

        let convId1 = UUID()
        let convId2 = UUID()
        let friendId = UUID()

        // Pass duplicates in targets
        let targets: [SharePostChatTarget] = [
            .conversation(convId1),
            .conversation(convId1),
            .conversation(convId2),
            .friend(friendId)
        ]

        let shareURL = URL(string: "https://splick.app/post/123")!
        let outcome = await sut.execute(
            shareURL: shareURL,
            note: "Look at this",
            targets: targets
        )

        XCTAssertTrue(outcome.didSendAny)
        XCTAssertEqual(outcome.sentCount, 3)
        XCTAssertEqual(outcome.failedCount, 0)

        let sent = await repo.sentMessages
        XCTAssertEqual(sent.count, 3)
        XCTAssertTrue(sent.allSatisfy(\.attachments.isEmpty))
    }

    func testSharePostToChatUseCase_forwardsGifAttachments() async {
        let repo = MockMessagingRepositoryForUseCases()
        let sendUseCase = SendMessageUseCase(repository: repo)
        let sut = SharePostToChatUseCase(repository: repo, sendMessageUseCase: sendUseCase)
        let gif = MessageImageAttachment(
            mediaId: nil,
            url: URL(string: "https://cdn.example/fun.gif")!,
            thumbnailURL: URL(string: "https://cdn.example/fun-preview.gif")
        )

        let outcome = await sut.execute(
            shareURL: URL(string: "https://splick.app/post/123")!,
            note: "😂",
            targets: [.conversation(UUID())],
            imageAttachments: [gif]
        )

        XCTAssertEqual(outcome.sentCount, 1)
        let sent = await repo.sentMessages
        XCTAssertEqual(sent.first?.attachments, [gif])
        XCTAssertTrue(sent.first?.body.contains("😂") == true)
    }
}
