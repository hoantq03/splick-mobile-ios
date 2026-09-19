import Foundation
import SplickDomain

public struct PeopleYouMayKnowSuggestion: Identifiable, Sendable, Equatable {
    public let user: UserSummary
    public let friendStatus: FriendRelationStatus
    public let sharedGroupName: String?

    public var id: UUID { user.id }

    public init(user: UserSummary, friendStatus: FriendRelationStatus, sharedGroupName: String?) {
        self.user = user
        self.friendStatus = friendStatus
        self.sharedGroupName = sharedGroupName
    }

    public func asSearchResult(subtitle: String?) -> UserSearchResult {
        UserSearchResult(
            user: UserSummary(
                id: user.id,
                username: user.username,
                displayName: user.displayName,
                subtitle: subtitle ?? user.subtitle,
                avatarURL: user.avatarURL
            ),
            friendStatus: friendStatus
        )
    }
}
