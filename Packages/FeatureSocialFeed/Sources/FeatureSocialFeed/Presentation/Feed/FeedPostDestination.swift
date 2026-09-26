import Foundation
import SwiftUI

/// Shared by the feed tab and nested segment pages. `@Published` invalidates
/// `FeedView`'s `NavigationStack` even when the tab pager skips `rootView` refresh.
@MainActor
public final class FeedNavigationStore: ObservableObject {
    @Published public var path = NavigationPath()

    public init() {}

    public func reset() {
        path = NavigationPath()
    }
}

public struct FeedPostDestination: Hashable {
    public let postId: UUID
    /// Album media id when the zoom should return to that thumbnail. Nil uses `postId`.
    public let zoomSourceId: UUID?
    public let mediaIndex: Int
    public let expandBillSplit: Bool
    /// When true, focuses the comment composer after navigation (e.g. "Write a comment…" on feed).
    public let focusComposerOnAppear: Bool
    public let commentId: UUID?
    /// When true (and `commentId` is nil), scroll to the first pending evidence comment.
    public let scrollToPendingEvidence: Bool

    public init(
        postId: UUID,
        zoomSourceId: UUID? = nil,
        mediaIndex: Int = 0,
        expandBillSplit: Bool = false,
        focusComposerOnAppear: Bool = false,
        commentId: UUID? = nil,
        scrollToPendingEvidence: Bool = false
    ) {
        self.postId = postId
        self.zoomSourceId = zoomSourceId
        self.mediaIndex = mediaIndex
        self.expandBillSplit = expandBillSplit
        self.focusComposerOnAppear = focusComposerOnAppear
        self.commentId = commentId
        self.scrollToPendingEvidence = scrollToPendingEvidence
    }
}

public struct PendingFeedPostNavigation: Equatable, Hashable, Identifiable {
    public var id: UUID { postId }

    public let postId: UUID
    public let expandBillSplit: Bool
    public let commentId: UUID?
    public let scrollToPendingEvidence: Bool

    public init(
        postId: UUID,
        expandBillSplit: Bool,
        commentId: UUID? = nil,
        scrollToPendingEvidence: Bool = false
    ) {
        self.postId = postId
        self.expandBillSplit = expandBillSplit
        self.commentId = commentId
        self.scrollToPendingEvidence = scrollToPendingEvidence
    }
}
