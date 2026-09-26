import XCTest
@testable import SplickDomain

final class PostDomainTests: XCTestCase {
    func testPostVersionComparisonAndCardContent() {
        let author = UserSummary(id: UUID(), username: "alice", displayName: "Alice")
        let companion = UserSummary(id: UUID(), username: "bob", displayName: "Bob")
        let imgUrl = URL(string: "https://example.com/1.jpg")!
        let now = Date()
        
        let post1 = Post(
            id: UUID(),
            author: author,
            imageURL: imgUrl,
            caption: "Caption",
            companions: [companion],
            mentions: []
        )
        
        XCTAssertEqual(post1.shareURL.absoluteString, "https://splick.app/post/\(post1.id.uuidString)")
        XCTAssertTrue(post1.hasSameCardContent(as: post1))
        
        let postWithNewVersion = post1.withVersion(5)
        XCTAssertEqual(postWithNewVersion.version, 5)
        XCTAssertEqual(postWithNewVersion.withVersion(5).version, 5)
        
        // Ensuring version relative to unchanged previous
        let postEnsuredSame = post1.ensuringVersion(relativeTo: postWithNewVersion)
        XCTAssertEqual(postEnsuredSame.version, 5)
        
        // Ensuring version relative to modified previous
        let postModified = post1.updating(caption: "Modified caption")
        let postEnsuredDiff = postModified.ensuringVersion(relativeTo: postWithNewVersion)
        XCTAssertEqual(postEnsuredDiff.version, 6)
        
        // Ensuring version relative to nil or different id
        let unrelated = Post(id: UUID(), author: author, imageURL: imgUrl, mentions: [])
        XCTAssertEqual(post1.ensuringVersion(relativeTo: nil).version, post1.version)
        XCTAssertEqual(post1.ensuringVersion(relativeTo: unrelated).version, post1.version)
    }

    func testPostBillReminders() {
        let author = UserSummary(id: UUID(), username: "alice", displayName: "Alice")
        let debtor = UserSummary(id: UUID(), username: "debtor", displayName: "Debtor")
        let lineId = UUID()
        let splitLine = PostBillSplitLine(
            id: lineId,
            user: debtor,
            amount: 50_000,
            isPaid: false,
            reminderCount: 0
        )
        let bill = PostBillSplit(totalAmount: 50_000, currency: "VND", splits: [splitLine])
        
        let post = Post(
            id: UUID(),
            author: author,
            imageURL: URL(string: "https://example.com/1.jpg")!,
            billSplit: bill,
            mentions: []
        )
        
        XCTAssertEqual(post.billSplitLine(for: debtor.id)?.reminderCount, 0)
        
        let incremented = post.incrementingBillReminders(for: [debtor.id])
        XCTAssertEqual(incremented.billSplitLine(for: debtor.id)?.reminderCount, 1)
        
        // Merge higher reminder counts
        let merged = post.mergingBillReminderCounts(from: incremented)
        XCTAssertEqual(merged.billSplitLine(for: debtor.id)?.reminderCount, 1)
    }

    func testPostOptimisticReactionsAndPreviews() {
        let author = UserSummary(id: UUID(), username: "alice", displayName: "Alice")
        let user1 = UserSummary(id: UUID(), username: "user1", displayName: "User 1")
        let post = Post(
            id: UUID(),
            author: author,
            imageURL: URL(string: "https://example.com/1.jpg")!,
            mentions: []
        )
        
        let reactionId = UUID()
        let reacted = post.applyingOptimisticReaction(emoji: "❤️", reactionId: reactionId, user: user1)
        XCTAssertEqual(reacted.reactionCount, 1)
        XCTAssertEqual(reacted.reactorCount, 1)
        XCTAssertEqual(reacted.reactionPreview.count, 1)
        XCTAssertEqual(reacted.reactionPreview.first?.compactLabel, "❤️×1")
        
        let previewTuple = reacted.reactionPreview(topLimit: 1)
        XCTAssertEqual(previewTuple.top.count, 1)
        XCTAssertEqual(previewTuple.otherPeopleCount, 0)
        
        // Remove reaction
        let unreacted = reacted.removingOptimisticReaction(reactionId: reactionId, emoji: "❤️", userId: user1.id)
        XCTAssertEqual(unreacted.reactionCount, 0)
        XCTAssertEqual(unreacted.reactorCount, 0)
        XCTAssertTrue(unreacted.reactionPreview.isEmpty)
    }

    func testPostCompanionsSummary() {
        let author = UserSummary(id: UUID(), username: "alice", displayName: "Alice")
        let c1 = UserSummary(id: UUID(), username: "c1", displayName: "Linh")
        let c2 = UserSummary(id: UUID(), username: "c2", displayName: "Nam")
        
        let postNoComp = Post(id: UUID(), author: author, imageURL: URL(string: "https://example.com/1.jpg")!, mentions: [])
        XCTAssertNil(postNoComp.companionsSummaryText())
        XCTAssertFalse(postNoComp.includesCompanion(userId: c1.id))
        XCTAssertFalse(postNoComp.includesCompanion(userId: nil))
        
        let postWithGroup = Post(
            id: UUID(),
            author: author,
            imageURL: URL(string: "https://example.com/1.jpg")!,
            companionGroupName: "Team Sài Gòn",
            mentions: []
        )
        XCTAssertEqual(postWithGroup.companionsSummaryText(), "Team Sài Gòn")
        
        let postWithComps = Post(
            id: UUID(),
            author: author,
            imageURL: URL(string: "https://example.com/1.jpg")!,
            companions: [c1, c2],
            mentions: []
        )
        XCTAssertTrue(postWithComps.includesCompanion(userId: c1.id))
        XCTAssertEqual(postWithComps.companionsSummaryText(maxNamed: 1), "Linh và +1 người khác")
        XCTAssertEqual(postWithComps.companionsSummaryText(maxNamed: 2), "Linh, Nam")
    }

    func testPostCodableRoundTrip() throws {
        let author = UserSummary(id: UUID(), username: "alice", displayName: "Alice")
        let post = Post(
            id: UUID(),
            author: author,
            imageURL: URL(string: "https://example.com/1.jpg")!,
            caption: "Roundtrip",
            mentions: []
        )
        
        let data = try JSONEncoder().encode(post)
        let decoded = try JSONDecoder().decode(Post.self, from: data)
        XCTAssertEqual(decoded.id, post.id)
        XCTAssertEqual(decoded.caption, "Roundtrip")
    }
}
