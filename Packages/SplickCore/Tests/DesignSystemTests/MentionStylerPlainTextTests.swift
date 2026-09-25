import XCTest
import DesignSystem

final class MentionStylerPlainTextTests: XCTestCase {
    private let unresolved = "Invalid user"
    private let taggedId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!

    func testResolvedFriendNameReplacesUuidMention() {
        let caption = "Dinner with <@" + taggedId.uuidString + ">"
        let text = MentionStyler.plainText(
            text: caption,
            displayNamesByUserId: [taggedId: "Linh nick"],
            unresolvedLabel: unresolved
        )
        XCTAssertEqual(text, "Dinner with Linh nick")
        XCTAssertFalse(text.contains(taggedId.uuidString))
    }

    func testMissingNameUsesUnresolvedLabelAndKeepsSurroundingText() {
        let caption = "Hello <@" + taggedId.uuidString + "> tonight"
        let text = MentionStyler.plainText(
            text: caption,
            displayNamesByUserId: [:],
            unresolvedLabel: unresolved
        )
        XCTAssertEqual(text, "Hello Invalid user tonight")
        XCTAssertFalse(text.lowercased().contains(taggedId.uuidString.lowercased()))
    }

    func testBlankNameUsesUnresolvedLabel() {
        let caption = "<@" + taggedId.uuidString + ">"
        let text = MentionStyler.plainText(
            text: caption,
            displayNamesByUserId: [taggedId: "   "],
            unresolvedLabel: unresolved
        )
        XCTAssertEqual(text, unresolved)
    }

    func testUuidShapedResolvedNameUsesUnresolvedLabel() {
        let caption = "tag <@" + taggedId.uuidString + ">"
        let text = MentionStyler.plainText(
            text: caption,
            displayNamesByUserId: [taggedId: taggedId.uuidString],
            unresolvedLabel: unresolved
        )
        XCTAssertEqual(text, "tag Invalid user")
    }

    func testTokenShapedResolvedNameUsesUnresolvedLabel() {
        let token = "<@" + taggedId.uuidString + ">"
        let text = MentionStyler.plainText(
            text: "hi \(token)",
            displayNamesByUserId: [taggedId: token],
            unresolvedLabel: unresolved
        )
        XCTAssertEqual(text, "hi Invalid user")
    }

    func testLegacyUsernameMentionStaysWhenUnresolved() {
        let text = MentionStyler.plainText(
            text: "hi @linh.ng",
            displayNamesByUserId: [:],
            unresolvedLabel: unresolved
        )
        XCTAssertEqual(text, "hi @linh.ng")
    }
}
