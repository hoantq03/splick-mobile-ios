import Foundation
import SplickDomain

struct FeedCachePayload: Codable, Sendable {
    let posts: [Post]
}
