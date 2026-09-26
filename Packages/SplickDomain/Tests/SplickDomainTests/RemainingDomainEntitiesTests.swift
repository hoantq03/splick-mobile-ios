import XCTest
@testable import SplickDomain

final class RemainingDomainEntitiesTests: XCTestCase {
    func testCustomEmojiAndEmojiKind() {
        let emoji = CustomEmoji(
            id: UUID(),
            ownerId: UUID(),
            shortcode: "cat_party",
            mediaUrl: URL(string: "https://example.com/cat.gif")!
        )
        XCTAssertEqual(emoji.colonCode, ":cat_party:")
        
        // EmojiKind from string
        let customKind = EmojiKind.from(":party_blob:")
        XCTAssertEqual(customKind, .custom(shortcode: "party_blob"))
        XCTAssertEqual(customKind.storageValue, ":party_blob:")
        
        let unicodeKind = EmojiKind.from("❤️")
        XCTAssertEqual(unicodeKind, .unicode("❤️"))
        XCTAssertEqual(unicodeKind.storageValue, "❤️")
        
        let invalidColon = EmojiKind.from(":hello:world:")
        XCTAssertEqual(invalidColon, .unicode(":hello:world:"))
    }

    func testStickerAndStickerCategory() {
        let sticker = Sticker(
            id: "sticker-123",
            url: URL(string: "https://example.com/s.webp")!,
            source: .klipy,
            width: 200,
            height: 200
        )
        XCTAssertNil(sticker.favoriteId)
        
        let favId = UUID()
        let favorited = sticker.withFavoriteId(favId)
        XCTAssertEqual(favorited.favoriteId, favId)
        XCTAssertEqual(favorited.id, "sticker-123")
    }

    func testConnectedAccountsAndAuthToken() {
        let google = ConnectedProvider(isLinked: true, detail: "google@splick.app")
        let email = ConnectedProvider(isLinked: true, detail: "email@splick.app")
        let phone = ConnectedProvider(isLinked: false, detail: nil)
        
        let connected = ConnectedAccounts(google: google, emailPassword: email, phone: phone)
        XCTAssertTrue(connected.google.isLinked)
        XCTAssertFalse(connected.phone.isLinked)
        
        let token = AuthToken(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresIn: 3600
        )
        XCTAssertEqual(token.tokenType, "Bearer")
        
        let user = User(id: UUID(), email: "u@splick.app", username: "u", displayName: "U")
        let session = AuthSession(user: user, token: token, isNewUser: true)
        XCTAssertTrue(session.isNewUser)
    }

    func testCommentSubmissionAttachment() {
        let data = "test image".data(using: .utf8)!
        let local = CommentSubmissionAttachment(
            kind: .image,
            data: data,
            mimeType: "image/jpeg",
            fileName: "test.jpg"
        )
        XCTAssertFalse(local.isRemoteOnly)
        XCTAssertFalse(local.isPreUploaded)
        
        let remote = CommentSubmissionAttachment(
            kind: .gif,
            remoteURL: URL(string: "https://giphy.com/1.gif")!
        )
        XCTAssertTrue(remote.isRemoteOnly)
        XCTAssertFalse(remote.isPreUploaded)
        
        let preUploaded = CommentSubmissionAttachment(
            kind: .image,
            uploadedMediaId: UUID(),
            url: URL(string: "https://cdn.splick.app/image.jpg")!,
            sizeBytes: 1024
        )
        XCTAssertFalse(preUploaded.isRemoteOnly)
        XCTAssertTrue(preUploaded.isPreUploaded)
    }

    func testUserAccountStatus() {
        XCTAssertEqual(UserAccountStatus.from(apiValue: "active"), .active)
        XCTAssertEqual(UserAccountStatus.from(apiValue: "INACTIVE"), .inactive)
        XCTAssertEqual(UserAccountStatus.from(apiValue: "locked"), .locked)
        XCTAssertEqual(UserAccountStatus.from(apiValue: "invalid"), .unknown)
        XCTAssertEqual(UserAccountStatus.from(apiValue: nil), .unknown)
        
        XCTAssertTrue(UserAccountStatus.active.allowsSignIn)
        XCTAssertFalse(UserAccountStatus.inactive.allowsSignIn)
        XCTAssertFalse(UserAccountStatus.locked.allowsSignIn)
        XCTAssertFalse(UserAccountStatus.unknown.allowsSignIn)
    }

    func testSpendingAnalyticsAndReplyDraft() {
        let point = SpendingTrendPoint(bucketStart: Date(), amount: 50_000)
        let breakdown = SpendingCategoryBreakdown(category: .food, amount: 50_000, percentage: 100)
        let analytics = SpendingAnalytics(
            trend: [point],
            categories: [breakdown],
            currency: "VND"
        )
        XCTAssertEqual(analytics.trend.count, 1)
        XCTAssertEqual(analytics.categories.first?.id, "FOOD")
        
        let draft = MessageReplyDraft(
            messageId: UUID(),
            senderId: UUID(),
            senderDisplayName: "Bob",
            bodySnippet: "Hi there",
            hasImageAttachment: false
        )
        let preview = draft.replyPreview
        XCTAssertEqual(preview.senderDisplayName, "Bob")
        XCTAssertEqual(preview.body, "Hi there")
    }
}
