import XCTest
import SplickDomain
@testable import FeatureSocialFeed

final class PostEditHistoryTimelineTests: XCTestCase {
    func testIncludesEverySnapshotAndDiffsAudienceAndTags() {
        let photoA = PostMediaItem(
            mediaURL: URL(string: "https://cdn.example/a.jpg")!,
            mediaType: .image
        )
        let photoB = PostMediaItem(
            mediaURL: URL(string: "https://cdn.example/b.jpg")!,
            mediaType: .image
        )
        let friend = UserSummary(id: UUID(), username: "ann", displayName: "Ann", avatarURL: nil)
        let previous = [
            PostEditRevision(
                editedAt: Date(timeIntervalSince1970: 1),
                caption: "hello",
                mediaItems: [photoA],
                audience: .friends,
                companions: [],
                revisionNumber: 1
            )
        ]
        let items = PostEditHistoryTimeline.items(
            previousNewestFirst: previous,
            currentCaption: "hello",
            currentMedia: [photoA, photoB],
            currentAt: Date(timeIntervalSince1970: 2),
            currentAudience: PostAudience(mode: .specificUsers, allowedUserIds: [friend.id]),
            currentCompanions: [friend]
        )
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items[0].isCurrent)
        XCTAssertEqual(items[1].change, .original)
        XCTAssertTrue(items[0].diff.mediaChanged)
        XCTAssertTrue(items[0].diff.audienceChanged)
        XCTAssertTrue(items[0].diff.companionsChanged)
        XCTAssertEqual(items[0].change, .mixed)
    }

    func testSkipsAudienceDiffWhenLegacyRevisionHasNullAudience() {
        let photo = PostMediaItem(
            mediaURL: URL(string: "https://cdn.example/a.jpg")!,
            mediaType: .image
        )
        let previous = [
            PostEditRevision(
                editedAt: Date(timeIntervalSince1970: 1),
                caption: "old",
                mediaItems: [photo]
            )
        ]
        let items = PostEditHistoryTimeline.items(
            previousNewestFirst: previous,
            currentCaption: "new",
            currentMedia: [photo],
            currentAt: Date(timeIntervalSince1970: 2),
            currentAudience: .friends,
            currentCompanions: []
        )
        XCTAssertTrue(items[0].diff.captionChanged)
        XCTAssertFalse(items[0].diff.audienceChanged)
        XCTAssertFalse(items[0].diff.companionsChanged)
        XCTAssertEqual(items[0].change, .caption)
    }
}
