import Foundation
import SplickDomain

public struct SharePostRecipient: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case conversation(Conversation)
        case friend(UserSummary)
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public var id: String {
        switch kind {
        case .conversation(let conversation):
            return "c-\(conversation.id.uuidString)"
        case .friend(let user):
            return "f-\(user.id.uuidString)"
        }
    }

    public var title: String {
        switch kind {
        case .conversation(let conversation):
            return conversation.displayTitle
        case .friend(let user):
            return user.preferredName
        }
    }

    public var subtitle: String? {
        switch kind {
        case .conversation(let conversation) where conversation.isGroup:
            return nil
        case .conversation(let conversation):
            return conversation.peer.map { "@\($0.username)" }
        case .friend(let user):
            return "@\(user.username)"
        }
    }

    public var avatarURL: URL? {
        switch kind {
        case .conversation(let conversation):
            if conversation.isGroup {
                return conversation.groupAvatarUrl.flatMap(URL.init(string:))
            }
            return conversation.peer?.avatarUrl.flatMap(URL.init(string:))
        case .friend(let user):
            return user.avatarURL
        }
    }

    public var userIdForAvatar: UUID? {
        switch kind {
        case .conversation(let conversation):
            return conversation.peer?.userId
        case .friend(let user):
            return user.id
        }
    }

    public var target: SharePostChatTarget {
        switch kind {
        case .conversation(let conversation):
            return .conversation(conversation.id)
        case .friend(let user):
            return .friend(user.id)
        }
    }
}
