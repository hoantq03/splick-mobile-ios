import Foundation

public struct FeedPostDestination: Hashable {
    public let postId: UUID
    public let mediaIndex: Int
    public let expandBillSplit: Bool
    /// When true, focuses the comment composer after navigation (e.g. "Write a comment…" on feed).
    public let focusComposerOnAppear: Bool
    public let commentId: UUID?

    public init(
        postId: UUID,
        mediaIndex: Int = 0,
        expandBillSplit: Bool = false,
        focusComposerOnAppear: Bool = false,
        commentId: UUID? = nil
    ) {
        self.postId = postId
        self.mediaIndex = mediaIndex
        self.expandBillSplit = expandBillSplit
        self.focusComposerOnAppear = focusComposerOnAppear
        self.commentId = commentId
    }
}

public struct PendingFeedPostNavigation: Equatable, Hashable {
    public let postId: UUID
    public let expandBillSplit: Bool
    public let commentId: UUID?

    public init(postId: UUID, expandBillSplit: Bool, commentId: UUID? = nil) {
        self.postId = postId
        self.expandBillSplit = expandBillSplit
        self.commentId = commentId
    }
}
