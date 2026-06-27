import Foundation

public struct FeedPostDestination: Hashable {
    public let postId: UUID
    public let mediaIndex: Int
    public let expandBillSplit: Bool

    public init(postId: UUID, mediaIndex: Int = 0, expandBillSplit: Bool = false) {
        self.postId = postId
        self.mediaIndex = mediaIndex
        self.expandBillSplit = expandBillSplit
    }
}

public struct PendingFeedPostNavigation: Equatable, Hashable {
    public let postId: UUID
    public let expandBillSplit: Bool

    public init(postId: UUID, expandBillSplit: Bool) {
        self.postId = postId
        self.expandBillSplit = expandBillSplit
    }
}
