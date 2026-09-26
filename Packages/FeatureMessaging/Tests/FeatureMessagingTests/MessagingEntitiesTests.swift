import XCTest
import SplickDomain
@testable import FeatureMessaging

final class MessagingEntitiesTests: XCTestCase {

    func testConversationPeer() {
        let userId = UUID()
        let peer = ConversationPeer(
            userId: userId,
            username: "hoan_dev",
            displayName: "Hoan Tran",
            avatarUrl: "https://avatar.png",
            isOnline: true,
            lastSeenAt: Date()
        )

        XCTAssertEqual(peer.userId, userId)
        XCTAssertEqual(peer.displayTitle, "Hoan Tran")

        // Username fallback when displayName is empty
        let peerEmptyDisplay = ConversationPeer(
            userId: userId,
            username: "hoan_dev",
            displayName: "",
            avatarUrl: nil
        )
        XCTAssertEqual(peerEmptyDisplay.displayTitle, "hoan_dev")

        // Username fallback when displayName is nil
        let peerNilDisplay = ConversationPeer(
            userId: userId,
            username: "hoan_dev",
            displayName: nil,
            avatarUrl: nil
        )
        XCTAssertEqual(peerNilDisplay.displayTitle, "hoan_dev")

        // updatingPresence
        let updated = peer.updatingPresence(isOnline: false, lastSeenAt: nil)
        XCTAssertEqual(updated.isOnline, false)
        XCTAssertEqual(updated.lastSeenAt, peer.lastSeenAt)

        let updatedLastSeen = peer.updatingPresence(isOnline: nil, lastSeenAt: Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(updatedLastSeen.isOnline, true)
        XCTAssertEqual(updatedLastSeen.lastSeenAt, Date(timeIntervalSince1970: 1000))
    }

    func testConversation() {
        let convId = UUID()
        let userId = UUID()
        let now = Date()
        let peer = ConversationPeer(userId: userId, username: "alice", displayName: "Alice Smith", avatarUrl: nil)

        let direct = Conversation(
            id: convId,
            type: .direct,
            unreadCount: 3,
            peer: peer,
            lastMessage: nil,
            createdAt: now,
            updatedAt: now
        )

        XCTAssertEqual(direct.displayTitle, "Alice Smith")
        XCTAssertFalse(direct.isGroup)
        XCTAssertFalse(direct.isRemovedFromGroup)

        // Fallback displayTitle when peer is nil
        let directNoPeer = Conversation(
            id: convId,
            type: .direct,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: now,
            updatedAt: now
        )
        XCTAssertEqual(directNoPeer.displayTitle, String(convId.uuidString.prefix(8)))

        // Group conversation
        let group = Conversation(
            id: convId,
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: "Splick Engineering",
            groupAvatarUrl: "https://grp.png",
            memberCount: 5,
            lastMessage: nil,
            createdAt: now,
            updatedAt: now
        )
        XCTAssertEqual(group.displayTitle, "Splick Engineering")
        XCTAssertTrue(group.isGroup)

        // Group conversation without groupName
        let groupNoName = Conversation(
            id: convId,
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: nil,
            lastMessage: nil,
            createdAt: now,
            updatedAt: now
        )
        XCTAssertEqual(groupNoName.displayTitle, "Group")

        // Mutating methods
        let updatedUnread = direct.updating(unreadCount: 10)
        XCTAssertEqual(updatedUnread.unreadCount, 10)

        let negativeUnread = direct.updating(unreadCount: -5)
        XCTAssertEqual(negativeUnread.unreadCount, 0)

        let updatedName = group.updating(groupName: "Mobile Core")
        XCTAssertEqual(updatedName.groupName, "Mobile Core")

        let updatedAvatar = group.updating(groupAvatarUrl: "https://newavatar.png")
        XCTAssertEqual(updatedAvatar.groupAvatarUrl, "https://newavatar.png")

        let newMsg = ChatMessage(
            id: UUID(),
            conversationId: convId,
            senderId: userId,
            body: "Live hello",
            clientMessageId: UUID(),
            createdAt: now,
            sequenceNo: 12
        )
        let updatedMsg = direct.updating(lastMessage: newMsg, unreadCount: 5, updatedAt: now.addingTimeInterval(60))
        XCTAssertEqual(updatedMsg.lastMessage?.body, "Live hello")
        XCTAssertEqual(updatedMsg.unreadCount, 5)

        let updatedSettings = direct.updatingNotificationSettings(enabled: false, sound: "chime", mutedUntil: nil)
        XCTAssertFalse(updatedSettings.notificationsEnabled)
        XCTAssertEqual(updatedSettings.notificationSound, "chime")
        XCTAssertTrue(updatedSettings.isMuted())

        let until = Date().addingTimeInterval(3600)
        let timed = direct.updatingNotificationSettings(enabled: false, sound: "chime", mutedUntil: until)
        XCTAssertTrue(timed.isMuted(now: Date()))
        XCTAssertFalse(timed.isMuted(now: until.addingTimeInterval(1)))

        let newPeer = ConversationPeer(userId: UUID(), username: "bob", displayName: "Bob", avatarUrl: nil)
        let updatedPeer = direct.updating(peer: newPeer)
        XCTAssertEqual(updatedPeer.peer?.username, "bob")

        let leaveTime = Date()
        let leftConv = group.updating(leftAt: leaveTime)
        XCTAssertTrue(leftConv.isRemovedFromGroup)
        XCTAssertEqual(leftConv.leftAt, leaveTime)
    }

    func testGroupChatMember() {
        let id = UUID()
        let userId = UUID()
        let avatar = URL(string: "https://splick.app/av.png")
        let member = GroupChatMember(
            id: id,
            userId: userId,
            username: "john",
            displayName: "John Doe",
            avatarURL: avatar,
            isOwner: true
        )

        XCTAssertEqual(member.id, id)
        XCTAssertEqual(member.userId, userId)
        XCTAssertEqual(member.username, "john")
        XCTAssertEqual(member.displayName, "John Doe")
        XCTAssertEqual(member.avatarURL, avatar)
        XCTAssertTrue(member.isOwner)
    }

    func testChatThreadRoute() {
        let conv = Conversation(
            id: UUID(),
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let highlightId = UUID()
        let route = ChatThreadRoute(conversation: conv, highlightMessageId: highlightId)

        XCTAssertEqual(route.conversation.id, conv.id)
        XCTAssertEqual(route.highlightMessageId, highlightId)
    }

    func testMessageSearchHitAndResult() {
        let msgId = UUID()
        let convId = UUID()
        let date = Date()
        let peer = ConversationPeer(userId: UUID(), username: "u", displayName: "D", avatarUrl: nil)
        let hit = MessageSearchHit(
            messageId: msgId,
            conversationId: convId,
            body: "Found text",
            createdAt: date,
            peer: peer
        )

        XCTAssertEqual(hit.id, msgId)
        XCTAssertEqual(hit.messageId, msgId)
        XCTAssertEqual(hit.conversationId, convId)
        XCTAssertEqual(hit.body, "Found text")
        XCTAssertEqual(hit.peer, peer)

        // MessagingSearchResult
        let hitResult = MessagingSearchResult.message(hit)
        XCTAssertEqual(hitResult.id, msgId)

        let userSummary = UserSummary(id: UUID(), username: "user_sum", displayName: "User Summary", avatarURL: nil)
        let userResult = MessagingSearchResult.user(userSummary)
        XCTAssertEqual(userResult.id, userSummary.id)

        let conversation = Conversation(
            id: convId,
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: "Trip",
            lastMessage: nil,
            createdAt: date,
            updatedAt: date
        )
        let conversationResult = MessagingSearchResult.conversation(conversation)
        XCTAssertEqual(conversationResult.id, convId)
    }
}
