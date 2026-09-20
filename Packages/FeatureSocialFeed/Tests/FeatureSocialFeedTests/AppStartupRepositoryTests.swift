import XCTest
import Networking
import Common
import SplickDomain
import Storage
import FeatureMessaging
import FeatureNotification
@testable import FeatureSocialFeed

final class AppStartupRepositoryTests: XCTestCase {

    private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
        var mockResponse: Any?
        var errorToThrow: Error?

        func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
            if let error = errorToThrow {
                throw error
            }
            if let response = mockResponse as? T {
                return response
            }
            throw NetworkError.unknown("Mock missing")
        }

        func request(_ endpoint: APIEndpoint) async throws {
            if let error = errorToThrow {
                throw error
            }
        }

        func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T {
            if let error = errorToThrow {
                throw error
            }
            if let response = mockResponse as? T {
                return response
            }
            throw NetworkError.unknown("Mock missing")
        }
    }

    func testFetchStartupDataSuccess() async throws {
        let apiClient = MockAPIClient()
        let repo = AppStartupRepository(apiClient: apiClient)

        let dto = StartupDataResponseDTO(
            badgeCounts: StartupBadgeCountsDTO(notifications: 2, friends: 1, expenses: 0, messages: 5, inbox: 3),
            currentStreak: 3,
            hasTodayPhoto: true,
            feedFirstPage: [],
            conversations: [
                StartupConversationDTO(
                    id: UUID(),
                    type: "DIRECT",
                    unreadCount: 2,
                    peer: StartupConversationPeerDTO(userId: UUID(), username: "peer1", displayName: "Peer 1", avatarUrl: nil),
                    groupName: nil,
                    groupAvatarUrl: nil,
                    memberCount: nil,
                    lastMessage: StartupMessageDTO(
                        id: UUID(),
                        conversationId: UUID(),
                        senderId: UUID(),
                        body: "Hello!",
                        clientMessageId: nil,
                        createdAt: Date(),
                        reactions: [
                            StartupReactionDTO(id: UUID(), emoji: "❤️", userId: UUID(), createdAt: Date())
                        ]
                    ),
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            customEmojis: [
                StartupCustomEmojiDTO(
                    id: UUID(),
                    ownerId: UUID(),
                    shortcode: "cat",
                    mediaUrl: "https://cdn.splick.com/cat.png",
                    createdAt: Date()
                )
            ]
        )
        apiClient.mockResponse = dto

        let data = try await repo.fetchStartupData()
        XCTAssertEqual(data.badgeCounts.notifications, 2)
        XCTAssertEqual(data.badgeCounts.messages, 5)
        XCTAssertEqual(data.badgeCounts.inbox, 3)
        XCTAssertEqual(data.conversations.count, 1)
        XCTAssertEqual(data.conversations.first?.lastMessage?.reactions.count, 1)
        XCTAssertEqual(data.emojis.count, 1)
        XCTAssertEqual(data.currentStreak, 3)
        XCTAssertTrue(data.hasTodayPhoto)
    }

    func testCachePayloadMapping() async {
        let userId = UUID()
        let data = AppStartupData(
            badgeCounts: TabBadgeCounts(notifications: 1, friends: 2, expenses: 3, messages: 4, inbox: 5),
            posts: [],
            conversations: [
                Conversation(
                    id: UUID(),
                    type: .group,
                    unreadCount: 1,
                    peer: nil,
                    groupName: "Test Group",
                    groupAvatarUrl: nil,
                    memberCount: 3,
                    lastMessage: ChatMessage(
                        id: UUID(),
                        conversationId: UUID(),
                        senderId: UUID(),
                        body: "Group message",
                        clientMessageId: UUID(),
                        createdAt: Date(),
                        reactions: []
                    ),
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            emojis: [
                CustomEmoji(
                    id: UUID(),
                    ownerId: UUID(),
                    shortcode: "dog",
                    mediaUrl: URL(string: "https://cdn.splick.com/dog.png")!,
                    createdAt: Date()
                )
            ],
            currentStreak: 7,
            hasTodayPhoto: false
        )

        let payload = StartupCacheMapper.toPayload(data)
        let restored = StartupCacheMapper.fromPayload(payload)

        XCTAssertEqual(restored.badgeCounts.notifications, 1)
        XCTAssertEqual(restored.badgeCounts.inbox, 5)
        XCTAssertEqual(restored.conversations.first?.groupName, "Test Group")
        XCTAssertEqual(restored.emojis.first?.shortcode, "dog")
        XCTAssertEqual(restored.currentStreak, 7)
        XCTAssertFalse(restored.hasTodayPhoto)

        let apiClient = MockAPIClient()
        let repo = AppStartupRepository(apiClient: apiClient)
        await repo.saveCached(data, userId: userId)
        let cached = await repo.loadCached(userId: userId)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.currentStreak, 7)
    }
}
