import XCTest
import SplickDomain
@testable import FeatureSocialFeed

final class FeedMapperTests: XCTestCase {
    func testToPostFromJSON() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "author": {
                "id": "22222222-2222-2222-2222-222222222222",
                "username": "alex",
                "displayName": "Alex Smith",
                "avatarUrl": "https://cdn.splick.com/avatar.jpg"
            },
            "imageUrl": "https://cdn.splick.com/post.jpg",
            "thumbnailUrl": "https://cdn.splick.com/thumb.jpg",
            "caption": "Lunch with friends",
            "createdAt": 1726750000,
            "reactionCount": 5,
            "reactorCount": 3,
            "commentCount": 2,
            "viewCount": 42,
            "feedKind": "CHECK_IN",
            "checkInPlace": "Hanoi Bistro"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let dto = try decoder.decode(PostDTO.self, from: json)
        let post = FeedMapper.toPost(dto)

        XCTAssertEqual(post.id.uuidString, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(post.author.username, "alex")
        XCTAssertEqual(post.author.displayName, "Alex Smith")
        XCTAssertEqual(post.author.avatarURL?.absoluteString, "https://cdn.splick.com/avatar.jpg")
        XCTAssertEqual(post.imageURL.absoluteString, "https://cdn.splick.com/post.jpg")
        XCTAssertEqual(post.caption, "Lunch with friends")
        XCTAssertEqual(post.reactionCount, 5)
        XCTAssertEqual(post.reactorCount, 3)
        XCTAssertEqual(post.commentCount, 2)
        XCTAssertEqual(post.viewCount, 42)
        XCTAssertEqual(post.checkInPlace, "Hanoi Bistro")
    }

    func testToCommentAndAttachments() throws {
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "author": {
                "id": "44444444-4444-4444-4444-444444444444",
                "username": "bob",
                "displayName": "Bob"
            },
            "body": "Looks great!",
            "createdAt": 1726751000,
            "commentType": "STANDARD",
            "attachments": [
                {
                    "id": "55555555-5555-5555-5555-555555555555",
                    "kind": "IMAGE",
                    "url": "https://cdn.splick.com/attach.jpg",
                    "fileName": "attach.jpg",
                    "sizeBytes": 1024
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let dto = try decoder.decode(CommentDTO.self, from: json)
        let comment = FeedMapper.toComment(dto)

        XCTAssertEqual(comment.id.uuidString, "33333333-3333-3333-3333-333333333333")
        XCTAssertEqual(comment.author.username, "bob")
        XCTAssertEqual(comment.text, "Looks great!")
        XCTAssertEqual(comment.attachments.count, 1)
        XCTAssertEqual(comment.attachments.first?.fileName, "attach.jpg")
        XCTAssertEqual(comment.attachments.first?.sizeBytes, 1024)
    }

    func testToReactionsAndSummaries() {
        let userId = UUID()
        let reactionDTO = ReactionDTO(
            id: UUID(),
            emoji: "🔥",
            userId: userId,
            createdAt: Date()
        )
        let reaction = FeedMapper.toReaction(reactionDTO)
        XCTAssertEqual(reaction.emoji, "🔥")
        XCTAssertEqual(reaction.userId, userId)

        let summaryDTO = ReactionUserSummaryDTO(
            user: AuthorDTO(id: userId, username: "user1", displayName: "User One", avatarUrl: nil, viewedAt: nil),
            emojiCounts: [EmojiCountDTO(emoji: "🔥", count: 2)]
        )
        let userReactionSummary = FeedMapper.toReactionUserSummary(summaryDTO)
        XCTAssertEqual(userReactionSummary.user.username, "user1")
        XCTAssertEqual(userReactionSummary.emojiCounts.first?.emoji, "🔥")
        XCTAssertEqual(userReactionSummary.emojiCounts.first?.count, 2)

        let postReactionsDTO = PostReactionsDTO(
            reactionCount: 10,
            reactorCount: 5,
            items: [summaryDTO]
        )
        let mapped = FeedMapper.toPostReactions(postReactionsDTO)
        XCTAssertEqual(mapped.reactionCount, 10)
        XCTAssertEqual(mapped.reactorCount, 5)
        XCTAssertEqual(mapped.items.count, 1)
    }

    func testToStreakAndAlbum() {
        let streakSummaryDTO = StreakSummaryDTO(currentStreak: 7, hasTodayPhoto: true)
        let streakSummary = FeedMapper.toStreakSummary(streakSummaryDTO)
        XCTAssertEqual(streakSummary.currentStreak, 7)
        XCTAssertTrue(streakSummary.hasTodayPhoto)

        let streakDayDTO = StreakDayDTO(
            date: "2026-09-19",
            firstPhotoUrl: "https://cdn.splick.com/streak.jpg",
            firstThumbnailUrl: nil,
            photoCount: 3
        )
        let streakDay = FeedMapper.toStreakDay(streakDayDTO)
        XCTAssertNotNil(streakDay)
        XCTAssertEqual(streakDay?.photoCount, 3)
        XCTAssertEqual(streakDay?.firstPhotoURL?.absoluteString, "https://cdn.splick.com/streak.jpg")

        // Invalid date format returns nil
        let invalidDateDTO = StreakDayDTO(date: "invalid-date", firstPhotoUrl: nil, firstThumbnailUrl: nil, photoCount: 0)
        XCTAssertNil(FeedMapper.toStreakDay(invalidDateDTO))

        let placeDTO = PostLocationDTO(placeId: "loc-1", displayName: "Da Nang Beach", lat: 16.05, lon: 108.2)
        let place = FeedMapper.toPlace(placeDTO)
        XCTAssertEqual(place?.placeId, "loc-1")
        XCTAssertEqual(place?.displayName, "Da Nang Beach")

        let emptyPlaceDTO = PostLocationDTO(placeId: nil, displayName: "  ", lat: nil, lon: nil)
        XCTAssertNil(FeedMapper.toPlace(emptyPlaceDTO))
    }

    func testToBillSplitAndAudience() {
        let lineDTO = PostBillSplitLineDTO(
            id: UUID(),
            user: AuthorDTO(id: UUID(), username: "dan", displayName: "Dan", avatarUrl: nil, viewedAt: nil),
            guest: nil,
            amount: "50000",
            isPaid: true,
            paymentStatus: "PAID",
            latestEvidenceCommentId: nil,
            lastRejectedAt: nil,
            reminderCount: 0,
            inviteUrl: nil
        )
        let billSplitDTO = PostBillSplitDTO(
            totalAmount: "100000",
            currency: "VND",
            splits: [lineDTO],
            tableInviteUrl: "https://splick.app/split/123"
        )
        let billSplit = FeedMapper.toBillSplit(billSplitDTO)
        XCTAssertEqual(billSplit.totalAmount, Decimal(100000))
        XCTAssertEqual(billSplit.currency, "VND")
        XCTAssertEqual(billSplit.splits.count, 1)
        XCTAssertEqual(billSplit.splits.first?.amount, Decimal(50000))
        XCTAssertEqual(billSplit.splits.first?.isPaid, true)

        let audienceDTO = PostAudienceDTO(
            mode: "friends",
            allowedGroupIds: nil,
            allowedUserIds: nil,
            excludedUserIds: nil
        )
        let audience = FeedMapper.toAudience(audienceDTO)
        XCTAssertEqual(audience.mode, .friends)
    }
}
