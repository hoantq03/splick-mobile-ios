import XCTest
@testable import SplickDomain

final class PostUserForMentionTests: XCTestCase {

    func testResolvesCompanionByUsernameIgnoringCase() {
        let companion = UserSummary(id: UUID(), username: "linhng", displayName: "Linh Nguyen")
        let post = makePost(
            caption: "hello @linhng",
            companions: [companion]
        )

        XCTAssertEqual(post.userForMentionUsername("linhng")?.id, companion.id)
        XCTAssertEqual(post.userForMentionUsername("@LinhNg")?.id, companion.id)
        XCTAssertEqual(post.mentionDisplayNamesByUsername["linhng"], "Linh Nguyen")
        XCTAssertNil(post.userForMentionUsername("unknown"))
    }

    func testResolvesDottedUsernameToDisplayName() {
        let tagged = UserSummary(id: UUID(), username: "linh.ng", displayName: "Linh Nguyen")
        let post = makePost(caption: "hello @linh.ng", mentions: [tagged])

        XCTAssertEqual(post.userForMentionUsername("linh.ng")?.id, tagged.id)
        XCTAssertEqual(post.mentionDisplayNamesByUsername["linh.ng"], "Linh Nguyen")
    }

    func testResolvesAuthorMention() {
        let author = UserSummary(id: UUID(), username: "hoantran", displayName: "Hoan Tran")
        let post = makePost(author: author, caption: "by @hoantran")

        XCTAssertEqual(post.userForMentionUsername("hoantran")?.id, author.id)
        XCTAssertEqual(post.userForMentionUsername("@hoantran")?.id, author.id)
    }

    func testResolvesMentionedUserByIdForDisplayName() {
        let tagged = UserSummary(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!,
            username: "linhng",
            displayName: "Linh Nguyen"
        )
        let post = makePost(
            caption: "<@\(tagged.id.uuidString)> hello",
            mentions: [tagged]
        )

        XCTAssertEqual(post.userForMentionUsername(tagged.id.uuidString)?.id, tagged.id)
        XCTAssertEqual(post.mentionDisplayNamesByUserId[tagged.id], "Linh Nguyen")
        XCTAssertEqual(post.mentionDisplayNamesByUsername[tagged.id.uuidString.lowercased()], "Linh Nguyen")
        XCTAssertEqual(post.mentionDisplayNamesByUsername["linhng"], "Linh Nguyen")
    }

    private func makePost(
        author: UserSummary = UserSummary(id: UUID(), username: "author", displayName: "Author"),
        caption: String? = nil,
        companions: [UserSummary] = [],
        mentions: [UserSummary] = []
    ) -> Post {
        Post(
            id: UUID(),
            author: author,
            imageURL: URL(string: "https://splick.app/media/preview.jpg")!,
            caption: caption,
            companions: companions,
            mentions: mentions
        )
    }
}
