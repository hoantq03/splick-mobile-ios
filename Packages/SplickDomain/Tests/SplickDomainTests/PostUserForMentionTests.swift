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

    func testResolvesAuthorMention() {
        let author = UserSummary(id: UUID(), username: "hoantran", displayName: "Hoan Tran")
        let post = makePost(author: author, caption: "by @hoantran")

        XCTAssertEqual(post.userForMentionUsername("hoantran")?.id, author.id)
        XCTAssertEqual(post.userForMentionUsername("@hoantran")?.id, author.id)
    }

    private func makePost(
        author: UserSummary = UserSummary(id: UUID(), username: "author", displayName: "Author"),
        caption: String? = nil,
        companions: [UserSummary] = []
    ) -> Post {
        Post(
            id: UUID(),
            author: author,
            imageURL: URL(string: "https://splick.app/media/preview.jpg")!,
            caption: caption,
            companions: companions
        )
    }
}
