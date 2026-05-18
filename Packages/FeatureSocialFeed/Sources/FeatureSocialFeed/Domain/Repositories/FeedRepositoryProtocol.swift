import Foundation
import SplickDomain

public protocol FeedRepositoryProtocol: Sendable {
    func fetchFeed(page: Int, limit: Int) async throws -> [Post]
    func fetchPost(id: UUID) async throws -> Post
    func addReaction(postId: UUID, emoji: String) async throws -> Reaction
    func removeReaction(postId: UUID, reactionId: UUID) async throws
    func createPost(_ input: CreatePostInput) async throws -> Post
    func deletePost(id: UUID) async throws
}
