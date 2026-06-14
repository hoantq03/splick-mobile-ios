import Foundation
import SplickDomain

/// Injected into FeatureMessaging to search friends without a hard dependency on FeatureFriends.
public protocol MessagingFriendSearchProviding: Sendable {
    func searchFriends(query: String) async throws -> [UserSummary]
}
