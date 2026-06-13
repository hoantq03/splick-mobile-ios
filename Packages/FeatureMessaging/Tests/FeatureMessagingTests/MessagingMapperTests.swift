import XCTest
import Foundation
@testable import FeatureMessaging

final class MessagingMapperTests: XCTestCase {

    private static let peerUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let conversationId = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!
    private static let messageId = UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000001")!
    private static let clientMsgId = UUID(uuidString: "cccccccc-0000-0000-0000-000000000001")!
    private static let senderId = UUID(uuidString: "dddddddd-0000-0000-0000-000000000001")!
    private static let createdAt = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let updatedAt = Date(timeIntervalSinceReferenceDate: 800_001_000)

    func test_toConversation_mapsAllFieldsIncludingPeer() {
        let peerDTO = ConversationPeerResponseDTO(
            userId: Self.peerUserId,
            username: "alice",
            displayName: "Alice Nguyen",
            avatarUrl: nil
        )
        let msgDTO = MessageResponseDTO(
            id: Self.messageId,
            conversationId: Self.conversationId,
            senderId: Self.senderId,
            body: "Hey there!",
            clientMessageId: Self.clientMsgId,
            createdAt: Self.createdAt
        )
        let dto = ConversationResponseDTO(
            id: Self.conversationId,
            unreadCount: 3,
            peer: peerDTO,
            lastMessage: msgDTO,
            createdAt: Self.createdAt,
            updatedAt: Self.updatedAt
        )

        let conversation = MessagingMapper.toConversation(dto)

        XCTAssertEqual(conversation.id, Self.conversationId)
        XCTAssertEqual(conversation.unreadCount, 3)
        XCTAssertNotNil(conversation.peer)
        XCTAssertEqual(conversation.peer?.userId, Self.peerUserId)
        XCTAssertEqual(conversation.peer?.username, "alice")
        XCTAssertEqual(conversation.peer?.displayName, "Alice Nguyen")
        XCTAssertNil(conversation.peer?.avatarUrl)
        XCTAssertEqual(conversation.peer?.displayTitle, "Alice Nguyen")
        XCTAssertEqual(conversation.lastMessage?.id, Self.messageId)
        XCTAssertEqual(conversation.lastMessage?.body, "Hey there!")
        XCTAssertEqual(conversation.createdAt, Self.createdAt)
        XCTAssertEqual(conversation.updatedAt, Self.updatedAt)
    }

    func test_toConversation_nilPeer_whenDTOHasNoPeer() {
        let dto = ConversationResponseDTO(
            id: Self.conversationId,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: Self.createdAt,
            updatedAt: Self.updatedAt
        )

        let conversation = MessagingMapper.toConversation(dto)

        XCTAssertNil(conversation.peer)
        XCTAssertNil(conversation.lastMessage)
        XCTAssertEqual(conversation.unreadCount, 0)
    }

    func test_toPeer_displayTitle_fallsBackToUsername_whenDisplayNameNil() {
        let dto = ConversationPeerResponseDTO(
            userId: Self.peerUserId,
            username: "bob_tran",
            displayName: nil,
            avatarUrl: nil
        )

        let peer = MessagingMapper.toPeer(dto)

        XCTAssertEqual(peer.displayTitle, "bob_tran")
    }

    func test_toPeer_displayTitle_fallsBackToUsername_whenDisplayNameEmpty() {
        let dto = ConversationPeerResponseDTO(
            userId: Self.peerUserId,
            username: "bob_tran",
            displayName: "",
            avatarUrl: nil
        )

        let peer = MessagingMapper.toPeer(dto)

        XCTAssertEqual(peer.displayTitle, "bob_tran")
    }
}
