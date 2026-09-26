import XCTest
@testable import SplickDomain

final class PostCommentAndThreadTests: XCTestCase {
    func testPostCommentProperties() {
        let user = UserSummary(id: UUID(), username: "alice", displayName: "Alice Nguyen")
        let now = Date()
        
        let comment = PostComment(
            id: UUID(),
            author: user,
            text: "Hello world",
            attachments: [
                CommentAttachment(
                    kind: .image,
                    url: URL(string: "https://example.com/img.jpg"),
                    fileName: "img.jpg",
                    thumbnailURL: nil,
                    sizeBytes: 1024
                )
            ],
            createdAt: now,
            updatedAt: now.addingTimeInterval(10),
            commentType: .standard,
            mentions: []
        )
        
        XCTAssertFalse(comment.isEvidence)
        XCTAssertFalse(comment.isEvidenceModeration)
        XCTAssertFalse(comment.isDeleted)
        XCTAssertTrue(comment.isEdited)
        XCTAssertEqual(comment.displayText, "Hello world")
        XCTAssertNil(comment.moderationOutcome)
        
        // Deleted comment
        let deletedComment = PostComment(
            id: UUID(),
            author: user,
            text: "Deleted comment",
            createdAt: now,
            deletedAt: now.addingTimeInterval(5),
            mentions: []
        )
        XCTAssertTrue(deletedComment.isDeleted)
        XCTAssertNil(deletedComment.displayText)
        XCTAssertFalse(deletedComment.isEdited)
        
        // Evidence comment
        let evidenceComment = PostComment(
            id: UUID(),
            author: user,
            commentType: .evidence,
            evidenceId: UUID(),
            splitId: UUID(),
            evidenceStatus: .pending,
            mentions: []
        )
        XCTAssertTrue(evidenceComment.isEvidence)
        XCTAssertFalse(evidenceComment.isEdited)
        
        // Evidence moderation comment
        let moderationComment = PostComment(
            id: UUID(),
            author: user,
            commentType: .evidenceModeration,
            evidenceStatus: .approved,
            mentions: []
        )
        XCTAssertTrue(moderationComment.isEvidenceModeration)
        XCTAssertEqual(moderationComment.moderationOutcome, .approved)
    }

    func testCommentThreadFilterAndArrayExtensions() {
        let user = UserSummary(id: UUID(), username: "bob", displayName: "Bob Tran")
        let root1 = PostComment(id: UUID(), author: user, text: "Root 1", commentType: .standard)
        let root2 = PostComment(id: UUID(), author: user, text: "Root 2 Evidence", commentType: .evidence)
        let reply1 = PostComment(id: UUID(), author: user, text: "Reply 1", parentCommentId: root1.id)
        let reply2 = PostComment(id: UUID(), author: user, text: "Reply 2 Deleted", parentCommentId: root1.id, deletedAt: Date())
        
        let allComments = [root1, root2, reply1, reply2]
        
        XCTAssertEqual(allComments.topLevel.count, 2)
        XCTAssertEqual(allComments.children(of: root1.id).count, 2)
        XCTAssertEqual(allComments.replies(to: root1.id).count, 2)
        XCTAssertEqual(allComments.activeCount, 3)
        
        // Filter tests
        XCTAssertTrue(CommentThreadFilter.all.includesRoot(root1))
        XCTAssertTrue(CommentThreadFilter.all.includesRoot(root2))
        XCTAssertFalse(CommentThreadFilter.all.includesRoot(reply1))
        
        XCTAssertTrue(CommentThreadFilter.comments.includesRoot(root1))
        XCTAssertFalse(CommentThreadFilter.comments.includesRoot(root2))
        XCTAssertFalse(CommentThreadFilter.evidence.includesRoot(root1))
        XCTAssertTrue(CommentThreadFilter.evidence.includesRoot(root2))
        
        XCTAssertEqual(CommentThreadFilter.comments.apiValue, "COMMENTS")
    }

    func testCommentThreadPagePaging() {
        let user = UserSummary(id: UUID(), username: "charlie", displayName: "Charlie")
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 2000)
        let t2 = Date(timeIntervalSince1970: 3000)
        
        let rootA = PostComment(id: UUID(), author: user, text: "Root A", createdAt: t0)
        let rootB = PostComment(id: UUID(), author: user, text: "Root B", createdAt: t1)
        let replyA1 = PostComment(id: UUID(), author: user, text: "Reply A1", parentCommentId: rootA.id, createdAt: t2)
        
        let page = CommentThreadPage.paging(
            from: [rootB, replyA1, rootA],
            page: 0,
            limit: 1,
            filter: .all
        )
        
        XCTAssertEqual(page.page, 0)
        XCTAssertEqual(page.limit, 1)
        XCTAssertTrue(page.hasMore)
        // Root A is first by timestamp + its subtree replyA1 should be included
        XCTAssertTrue(page.comments.contains(where: { $0.id == rootA.id }))
        XCTAssertTrue(page.comments.contains(where: { $0.id == replyA1.id }))
        XCTAssertFalse(page.comments.contains(where: { $0.id == rootB.id }))
    }
}
