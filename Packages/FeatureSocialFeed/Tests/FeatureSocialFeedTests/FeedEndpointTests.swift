import XCTest
import Networking
import SplickDomain
@testable import FeatureSocialFeed

final class FeedEndpointTests: XCTestCase {
    func testFeedEndpointsPathsAndMethods() {
        let postId = UUID()
        let authorId = UUID()
        let reactionId = UUID()
        let evidenceId = UUID()
        let now = Date()

        // Feed list
        let feedEp = FeedEndpoint.feed(page: 1, limit: 10, authorId: authorId)
        XCTAssertEqual(feedEp.path, "/v1/feed")
        XCTAssertEqual(feedEp.method, .get)
        XCTAssertEqual(feedEp.queryItems?.count, 3)

        let feedEpNoAuthor = FeedEndpoint.feed(page: 0, limit: 20, authorId: nil)
        XCTAssertEqual(feedEpNoAuthor.queryItems?.count, 2)

        // Feed ahead count
        let aheadEp = FeedEndpoint.feedAheadCount(afterCreatedAt: now, afterId: postId)
        XCTAssertEqual(aheadEp.path, "/v1/feed/ahead-count")
        XCTAssertEqual(aheadEp.method, .get)
        XCTAssertEqual(aheadEp.queryItems?.count, 2)

        // Post CRUD
        let postGet = FeedEndpoint.post(id: postId)
        XCTAssertEqual(postGet.path, "/v1/feed/posts/\(postId)")
        XCTAssertEqual(postGet.method, .get)

        let postDelete = FeedEndpoint.deletePost(id: postId)
        XCTAssertEqual(postDelete.path, "/v1/feed/posts/\(postId)")
        XCTAssertEqual(postDelete.method, .delete)

        let postEdits = FeedEndpoint.postEdits(id: postId)
        XCTAssertEqual(postEdits.path, "/v1/feed/posts/\(postId)/edits")
        XCTAssertEqual(postEdits.method, .get)

        // Reactions
        let reactionsList = FeedEndpoint.postReactions(postId: postId)
        XCTAssertEqual(reactionsList.path, "/v1/feed/posts/\(postId)/reactions")
        XCTAssertEqual(reactionsList.method, .get)

        let removeReaction = FeedEndpoint.removeReaction(postId: postId, reactionId: reactionId)
        XCTAssertEqual(removeReaction.path, "/v1/feed/posts/\(postId)/reactions/\(reactionId)")
        XCTAssertEqual(removeReaction.method, .delete)

        // Streak
        let streakSummary = FeedEndpoint.streakSummary
        XCTAssertEqual(streakSummary.path, "/v1/feed/streak")
        XCTAssertEqual(streakSummary.method, .get)

        let streakCalendar = FeedEndpoint.streakCalendar(year: 2026, month: 9)
        XCTAssertEqual(streakCalendar.path, "/v1/feed/streak/calendar")
        XCTAssertEqual(streakCalendar.method, .get)
        XCTAssertEqual(streakCalendar.queryItems?.count, 2)

        let streakPhotos = FeedEndpoint.streakDayPhotos(date: "2026-09-19")
        XCTAssertEqual(streakPhotos.path, "/v1/feed/streak/days/2026-09-19/photos")
        XCTAssertEqual(streakPhotos.method, .get)

        // Evidence
        let approveEv = FeedEndpoint.approvePaymentEvidence(postId: postId, evidenceId: evidenceId)
        XCTAssertEqual(approveEv.path, "/v1/feed/posts/\(postId)/payments/evidence/\(evidenceId)/approve")
        XCTAssertEqual(approveEv.method, .post)

        // Locations
        let searchLoc = FeedEndpoint.searchLocations(query: "Coffee", limit: 5, lat: 21.0, lon: 105.8)
        XCTAssertEqual(searchLoc.path, "/v1/feed/locations/search")
        XCTAssertEqual(searchLoc.method, .get)
        XCTAssertEqual(searchLoc.queryItems?.count, 4)

        let nearbyLoc = FeedEndpoint.nearbyLocations(lat: 21.0, lon: 105.8, radius: 1000, limit: 10)
        XCTAssertEqual(nearbyLoc.path, "/v1/feed/locations/nearby")
        XCTAssertEqual(nearbyLoc.method, .get)
        XCTAssertEqual(nearbyLoc.queryItems?.count, 4)
    }

    func testAppStartupEndpoint() {
        let ep = AppStartupEndpoint.startup
        XCTAssertEqual(ep.path, "/v1/app/startup")
        XCTAssertEqual(ep.method, .get)
        XCTAssertNil(ep.queryItems)
        XCTAssertNil(ep.body)
    }
}
