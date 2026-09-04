import Foundation
import FeatureMessaging
import FeatureNotification
import SplickDomain

public struct AppStartupData: Sendable {
    public let badgeCounts: TabBadgeCounts
    public let posts: [Post]
    public let conversations: [Conversation]
    public let emojis: [CustomEmoji]
    public let currentStreak: Int
    public let hasTodayPhoto: Bool

    public init(
        badgeCounts: TabBadgeCounts,
        posts: [Post],
        conversations: [Conversation],
        emojis: [CustomEmoji],
        currentStreak: Int,
        hasTodayPhoto: Bool
    ) {
        self.badgeCounts = badgeCounts
        self.posts = posts
        self.conversations = conversations
        self.emojis = emojis
        self.currentStreak = currentStreak
        self.hasTodayPhoto = hasTodayPhoto
    }
}
