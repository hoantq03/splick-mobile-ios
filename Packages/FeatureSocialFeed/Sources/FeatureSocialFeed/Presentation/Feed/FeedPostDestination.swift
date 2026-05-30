import Foundation

/// Navigation value for opening post detail while preserving the visible media page.
struct FeedPostDestination: Hashable {
    let postId: UUID
    let mediaIndex: Int
}
