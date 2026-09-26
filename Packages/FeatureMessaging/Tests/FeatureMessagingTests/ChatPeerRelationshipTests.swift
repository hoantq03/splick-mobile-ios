import XCTest
import SplickDomain
import Common
@testable import FeatureMessaging

final class ChatPeerRelationshipTests: XCTestCase {

    func testRelationStateProperties() {
        XCTAssertFalse(ChatPeerRelationState.unknown.showsAddFriendBanner)
        XCTAssertFalse(ChatPeerRelationState.friends.showsAddFriendBanner)
        XCTAssertFalse(ChatPeerRelationState.blocked.showsAddFriendBanner)
        XCTAssertTrue(ChatPeerRelationState.stranger.showsAddFriendBanner)
        XCTAssertTrue(ChatPeerRelationState.requestSent.showsAddFriendBanner)
        XCTAssertTrue(ChatPeerRelationState.requestReceived.showsAddFriendBanner)

        XCTAssertTrue(ChatPeerRelationState.blocked.isBlocked)
        XCTAssertFalse(ChatPeerRelationState.friends.isBlocked)

        XCTAssertTrue(ChatPeerRelationState.friends.canRemoveFriend)
        XCTAssertFalse(ChatPeerRelationState.stranger.canRemoveFriend)

        XCTAssertTrue(ChatPeerRelationState.friends.canComposeDirectMessages)
        XCTAssertFalse(ChatPeerRelationState.unknown.canComposeDirectMessages)
        XCTAssertFalse(ChatPeerRelationState.stranger.canComposeDirectMessages)
        XCTAssertFalse(ChatPeerRelationState.requestSent.canComposeDirectMessages)
        XCTAssertFalse(ChatPeerRelationState.requestReceived.canComposeDirectMessages)
        XCTAssertFalse(ChatPeerRelationState.blocked.canComposeDirectMessages)
    }

    @MainActor
    func testInertViewModelDoesNothing() async {
        let vm = ChatPeerRelationshipViewModel.inert()
        XCTAssertFalse(vm.isActive)
        XCTAssertFalse(vm.showsAddFriendBanner)
        XCTAssertFalse(vm.isBlocked)
        XCTAssertFalse(vm.canRemoveFriend)
        XCTAssertTrue(vm.canComposeMessages)

        await vm.loadIfNeeded()
        await vm.refresh()
        await vm.blockUser()
        await vm.unblockUser()
        await vm.removeFriend()
        await vm.addFriend()
        await vm.acceptFriendRequest()
        await vm.cancelFriendRequest()

        XCTAssertEqual(vm.status, .unknown)
    }

    @MainActor
    func testActiveViewModelActions() async {
        let peerId = UUID()
        let stateBox = SendableStateBox()

        let actions = ChatPeerRelationshipActions(
            fetchStatus: { id in
                XCTAssertEqual(id, peerId)
                return stateBox.currentStatus
            },
            blockUser: { id in
                XCTAssertEqual(id, peerId)
                stateBox.didCallBlock = true
                stateBox.currentStatus = .blocked
            },
            unblockUser: { id in
                XCTAssertEqual(id, peerId)
                stateBox.didCallUnblock = true
                stateBox.currentStatus = .stranger
            },
            removeFriend: { id in
                XCTAssertEqual(id, peerId)
                stateBox.didCallRemove = true
                stateBox.currentStatus = .stranger
            },
            addFriend: { id in
                XCTAssertEqual(id, peerId)
                stateBox.didCallAdd = true
                stateBox.currentStatus = .requestSent
            },
            acceptFriendRequest: { id in
                XCTAssertEqual(id, peerId)
                stateBox.didCallAccept = true
                stateBox.currentStatus = .friends
            },
            cancelFriendRequest: { id in
                XCTAssertEqual(id, peerId)
                stateBox.didCallCancel = true
                stateBox.currentStatus = .stranger
            }
        )

        let vm = ChatPeerRelationshipViewModel(peerUserId: peerId, actions: actions, isActive: true)
        XCTAssertTrue(vm.isActive)

        await vm.loadIfNeeded()
        XCTAssertEqual(vm.status, .stranger)
        XCTAssertTrue(vm.showsAddFriendBanner)
        XCTAssertFalse(vm.canComposeMessages)

        await vm.addFriend()
        XCTAssertTrue(stateBox.didCallAdd)
        XCTAssertEqual(vm.status, .requestSent)
        XCTAssertFalse(vm.canComposeMessages)

        await vm.acceptFriendRequest()
        XCTAssertTrue(stateBox.didCallAccept)
        XCTAssertEqual(vm.status, .friends)
        XCTAssertTrue(vm.canRemoveFriend)
        XCTAssertTrue(vm.canComposeMessages)

        await vm.removeFriend()
        XCTAssertTrue(stateBox.didCallRemove)
        XCTAssertEqual(vm.status, .stranger)

        await vm.blockUser()
        XCTAssertTrue(stateBox.didCallBlock)
        XCTAssertEqual(vm.status, .blocked)
        XCTAssertTrue(vm.isBlocked)

        await vm.unblockUser()
        XCTAssertTrue(stateBox.didCallUnblock)
        XCTAssertEqual(vm.status, .stranger)

        await vm.cancelFriendRequest()
        XCTAssertTrue(stateBox.didCallCancel)
        XCTAssertEqual(vm.status, .stranger)
    }

    @MainActor
    func testActionErrorsFallbackToRefresh() async {
        let peerId = UUID()
        let actions = ChatPeerRelationshipActions(
            fetchStatus: { _ in .stranger },
            blockUser: { _ in throw URLError(.badServerResponse) },
            unblockUser: { _ in throw URLError(.badServerResponse) },
            removeFriend: { _ in throw URLError(.badServerResponse) },
            addFriend: { _ in throw URLError(.badServerResponse) },
            acceptFriendRequest: { _ in throw URLError(.badServerResponse) },
            cancelFriendRequest: { _ in throw URLError(.badServerResponse) }
        )

        let vm = ChatPeerRelationshipViewModel(peerUserId: peerId, actions: actions, isActive: true)
        await vm.blockUser()
        XCTAssertEqual(vm.status, .stranger)

        await vm.unblockUser()
        XCTAssertEqual(vm.status, .stranger)

        await vm.removeFriend()
        XCTAssertEqual(vm.status, .stranger)

        await vm.addFriend()
        XCTAssertEqual(vm.status, .stranger)

        await vm.acceptFriendRequest()
        XCTAssertEqual(vm.status, .stranger)

        await vm.cancelFriendRequest()
        XCTAssertEqual(vm.status, .stranger)
    }

    func testFriendDisplayNameStoreExtension() async {
        let store = FriendDisplayNameStore()
        let peerUserId = UUID()
        let peer = ConversationPeer(
            userId: peerUserId,
            username: "john_doe",
            displayName: "John",
            avatarUrl: "https://example.com/avatar.png",
            isOnline: true,
            lastSeenAt: nil
        )

        let resolvedPeer = await store.resolvePeer(peer)
        XCTAssertEqual(resolvedPeer.userId, peerUserId)
        XCTAssertEqual(resolvedPeer.displayName, "John")

        let conv = Conversation(
            id: UUID(),
            type: .direct,
            unreadCount: 0,
            peer: peer,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let resolvedConv = await store.resolve(conv)
        XCTAssertEqual(resolvedConv.peer?.displayName, "John")

        let convList = await store.resolve([conv])
        XCTAssertEqual(convList.count, 1)

        let groupConv = Conversation(
            id: UUID(),
            type: .group,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let resolvedGroup = await store.resolve(groupConv)
        XCTAssertNil(resolvedGroup.peer)
    }
}

private final class SendableStateBox: @unchecked Sendable {
    var currentStatus: ChatPeerRelationState = .stranger
    var didCallBlock = false
    var didCallUnblock = false
    var didCallRemove = false
    var didCallAdd = false
    var didCallAccept = false
    var didCallCancel = false
}
