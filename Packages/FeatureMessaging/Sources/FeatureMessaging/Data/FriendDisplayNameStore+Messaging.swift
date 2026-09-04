import Foundation
import Common
import SplickDomain

extension FriendDisplayNameStore {
    public func resolvePeer(_ peer: ConversationPeer) -> ConversationPeer {
        let resolved = resolve(
            UserSummary(
                id: peer.userId,
                username: peer.username,
                displayName: peer.displayName ?? peer.username,
                avatarURL: peer.avatarUrl.flatMap { URL(string: $0) }
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

    public func resolve(_ conversation: Conversation) -> Conversation {
        guard let peer = conversation.peer else { return conversation }
        return conversation.updating(peer: resolvePeer(peer))
    }

    public func resolve(_ conversations: [Conversation]) -> [Conversation] {
        conversations.map(resolve)
    }
}
