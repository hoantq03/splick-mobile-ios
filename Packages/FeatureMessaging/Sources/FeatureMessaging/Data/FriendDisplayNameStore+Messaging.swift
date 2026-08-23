import Common
import SplickDomain

extension FriendDisplayNameStore {
    func resolvePeer(_ peer: ConversationPeer) -> ConversationPeer {
        let resolved = resolve(
            UserSummary(
                id: peer.userId,
                username: peer.username,
                displayName: peer.displayName ?? peer.username,
                avatarURL: peer.avatarUrl.flatMap(URL.init(string:))
            )
        )
        return ConversationPeer(
            userId: peer.userId,
            username: peer.username,
            displayName: resolved.displayName,
            avatarUrl: peer.avatarUrl,
            isOnline: peer.isOnline,
            lastSeenAt: peer.lastSeenAt
        )
    }

    func resolve(_ conversation: Conversation) -> Conversation {
        guard let peer = conversation.peer else { return conversation }
        return conversation.updating(peer: resolvePeer(peer))
    }

    func resolve(_ conversations: [Conversation]) -> [Conversation] {
        conversations.map(resolve)
    }
}
