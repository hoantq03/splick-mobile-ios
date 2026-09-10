import XCTest
import SplickDomain

final class PostReactionSummaryTests: XCTestCase {
    func testApplyingReactionOnListPreviewPinsActorAndBumpsCounts() {
        let actor = UserSummary(id: UUID(), username: "me", displayName: "Me")
        let other = UserSummary(id: UUID(), username: "them", displayName: "Them")
        let post = Post(
            id: UUID(),
            author: other,
            imageURL: URL(string: "https://cdn.example.com/p.jpg")!,
            reactionCount: 4,
            reactorCount: 1,
            reactionPreview: [
                UserReactionSummary(
                    user: other,
                    emojiCounts: [UserEmojiCount(emoji: "😂", count: 4)]
                )
            ]
        )

        let updated = post.applyingOptimisticReaction(
            emoji: "❤️",
            reactionId: UUID(),
            user: actor
        )

        XCTAssertTrue(updated.reactions.isEmpty)
        XCTAssertEqual(updated.reactionCount, 5)
        XCTAssertEqual(updated.reactorCount, 2)
        XCTAssertEqual(updated.reactionPreview.first?.userId, actor.id)
        XCTAssertEqual(updated.reactionPreview(topLimit: 3).otherPeopleCount, 0)
    }

    func testUserReactionSummariesUsesServerPreviewWhenReactionsEmpty() {
        let other = UserSummary(id: UUID(), username: "them", displayName: "Them")
        let summary = UserReactionSummary(
            user: other,
            emojiCounts: [UserEmojiCount(emoji: "🔥", count: 2)]
        )
        let post = Post(
            id: UUID(),
            author: other,
            imageURL: URL(string: "https://cdn.example.com/p.jpg")!,
            reactionCount: 2,
            reactorCount: 1,
            reactionPreview: [summary]
        )

        XCTAssertEqual(post.userReactionSummaries(), [summary])
    }
}
