import XCTest
@testable import Common
import SplickDomain

final class FriendDisplayNameStoreMentionTests: XCTestCase {

    func testResolvePostKeepsMentionsAndAppliesNickname() async {
        let taggedId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!
        let tagged = UserSummary(id: taggedId, username: "linhng", displayName: "Linh Nguyen")
        let commentMention = UserSummary(id: UUID(), username: "minhthu", displayName: "Minh Thu")
        let store = FriendDisplayNameStore()
        await store.upsert(
            from: UserSummary(
                id: taggedId,
                username: "linhng",
                displayName: "Linh nick",
                subtitle: "Linh Nguyen"
            )
        )

        let comment = PostComment(
            author: UserSummary(id: UUID(), username: "author", displayName: "Author"),
            text: "hi <@\(commentMention.id.uuidString)>",
            mentions: [commentMention]
        )
        let post = Post(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "author", displayName: "Author"),
            imageURL: URL(string: "https://splick.app/media/preview.jpg")!,
            caption: "hello <@\(taggedId.uuidString)>",
            comments: [comment],
            mentions: [tagged],
            editedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let resolved = await store.resolve(post)

        XCTAssertEqual(resolved.mentions.map(\.id), [taggedId])
        XCTAssertEqual(resolved.mentions.first?.displayName, "Linh nick")
        XCTAssertEqual(resolved.mentionDisplayNamesByUserId[taggedId], "Linh nick")
        XCTAssertEqual(resolved.comments.first?.mentions.map(\.id), [commentMention.id])
        XCTAssertEqual(resolved.comments.first?.mentions.first?.displayName, "Minh Thu")
        XCTAssertEqual(resolved.editedAt, post.editedAt)
    }
}
