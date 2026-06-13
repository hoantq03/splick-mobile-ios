import Foundation
import SplickDomain

/// Protocol injected into FeatureMessaging to load friends list without a hard dependency on FeatureFriends.
public protocol FriendsListProviding: Sendable {
    func fetchFriends() async throws -> [UserSummary]
}
