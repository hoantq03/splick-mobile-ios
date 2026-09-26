import XCTest
import Networking
import SplickDomain
import Storage
@testable import FeatureNotification

final class NotificationEndpointsAndMappersTests: XCTestCase {
    func testNotificationEndpoints() {
        let notifId = UUID()

        // List
        let listWithCategory = NotificationEndpoint.list(page: 1, limit: 10, category: "SOCIAL")
        XCTAssertEqual(listWithCategory.path, "/v1/notifications")
        XCTAssertEqual(listWithCategory.method, .get)
        XCTAssertEqual(listWithCategory.queryItems?.count, 3)

        let listNoCategory = NotificationEndpoint.list(page: 0, limit: 20, category: nil)
        XCTAssertEqual(listNoCategory.queryItems?.count, 2)

        // Mark read
        let markRead = NotificationEndpoint.markRead(id: notifId)
        XCTAssertEqual(markRead.path, "/v1/notifications/\(notifId)/read")
        XCTAssertEqual(markRead.method, .post)

        // Mark clicked
        let markClicked = NotificationEndpoint.markClicked(id: notifId)
        XCTAssertEqual(markClicked.path, "/v1/notifications/\(notifId)/click")
        XCTAssertEqual(markClicked.method, .post)

        // Mark all read
        let markAll = NotificationEndpoint.markAllRead
        XCTAssertEqual(markAll.path, "/v1/notifications/read-all")
        XCTAssertEqual(markAll.method, .post)

        // Unread count
        let unread = NotificationEndpoint.unreadCount
        XCTAssertEqual(unread.path, "/v1/notifications/unread-count")
        XCTAssertEqual(unread.method, .get)

        // Badge counts
        let badges = NotificationEndpoint.badgeCounts
        XCTAssertEqual(badges.path, "/v1/notifications/badge-counts")
        XCTAssertEqual(badges.method, .get)

        // Mark inbox seen
        let seen = NotificationEndpoint.markInboxSeen
        XCTAssertEqual(seen.path, "/v1/notifications/seen")
        XCTAssertEqual(seen.method, .post)
    }

    func testDeviceEndpoints() {
        let req = RegisterPushDeviceRequestDTO(
            token: "device-token-123",
            platform: "IOS",
            bundleId: "com.splick.app",
            environment: "DEVELOPMENT"
        )
        let register = DeviceEndpoint.register(req)
        XCTAssertEqual(register.path, "/v1/devices")
        XCTAssertEqual(register.method, .post)
        XCTAssertNotNil(register.body)

        let unregister = DeviceEndpoint.unregister(token: "token-to-delete")
        XCTAssertEqual(unregister.path, "/v1/devices/token-to-delete")
        XCTAssertEqual(unregister.method, .delete)
        XCTAssertNil(unregister.body)
    }

    func testNotificationMapperAndDTOs() throws {
        let notifId = UUID()
        let actorId = UUID()
        let postId = UUID()
        let commentId = UUID()
        let now = Date()

        let json = """
        {
            "id": "\(notifId.uuidString)",
            "type": "FRIEND_REQUEST_SENT",
            "title": "New Friend Request",
            "body": "John sent you a friend request",
            "isRead": false,
            "referenceId": "\(notifId.uuidString)",
            "actorUserId": "\(actorId.uuidString)",
            "actorAvatarUrl": "https://cdn.splick.com/avatar.jpg",
            "destination": {
                "screen": "POST_DETAIL",
                "postId": "\(postId.uuidString)",
                "commentId": "\(commentId.uuidString)"
            },
            "createdAt": 1726750000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let dto = try decoder.decode(NotificationResponseDTO.self, from: json)

        let domain = NotificationMapper.toNotification(dto)
        XCTAssertEqual(domain.id, notifId)
        XCTAssertEqual(domain.type, .friendRequestSent)
        XCTAssertEqual(domain.title, "New Friend Request")
        XCTAssertEqual(domain.body, "John sent you a friend request")
        XCTAssertFalse(domain.isRead)
        XCTAssertEqual(domain.actorUserId, actorId)
        XCTAssertEqual(domain.actorAvatarURL?.absoluteString, "https://cdn.splick.com/avatar.jpg")
        XCTAssertEqual(domain.destination?.screen, NotificationScreen.postDetail)
        XCTAssertEqual(domain.destination?.postId, postId)
        XCTAssertEqual(domain.destination?.commentId, commentId)
    }

    func testBadgeCountsDTO() {
        let dtoWithInbox = BadgeCountsDTO(notifications: 3, friends: 2, expenses: 1, messages: 5, inbox: 4)
        XCTAssertEqual(dtoWithInbox.inboxCount, 4)

        let dtoNilInbox = BadgeCountsDTO(notifications: 1, friends: 0, expenses: 0, messages: 0, inbox: nil)
        XCTAssertEqual(dtoNilInbox.inboxCount, 0)
    }

    func testPushNotificationActionsAndReactions() {
        XCTAssertEqual(PushNotificationAction.reactionEmoji(for: PushNotificationAction.messageReactHeart), "❤️")
        XCTAssertEqual(PushNotificationAction.reactionEmoji(for: PushNotificationAction.messageReactThumb), "👍")
        XCTAssertEqual(PushNotificationAction.reactionEmoji(for: PushNotificationAction.messageReactLaugh), "😂")
        XCTAssertNil(PushNotificationAction.reactionEmoji(for: "UNKNOWN"))
    }
}
