import Foundation
import SplickDomain

public protocol FeedRepositoryProtocol: Sendable {
    func fetchFeed(page: Int, limit: Int) async throws -> [Post]
    func fetchPost(id: UUID) async throws -> Post
    func addReaction(postId: UUID, emoji: String) async throws -> Reaction
    func removeReaction(postId: UUID, reactionId: UUID) async throws
    func createPost(imageData: Data, caption: String?, groupId: UUID?) async throws -> Post
}
