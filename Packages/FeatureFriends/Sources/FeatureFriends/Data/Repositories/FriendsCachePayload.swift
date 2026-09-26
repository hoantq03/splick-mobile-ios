import Foundation
import SplickDomain

struct FriendsCachePayload: Codable, Sendable {
    let friends: [UserSummary]
}
