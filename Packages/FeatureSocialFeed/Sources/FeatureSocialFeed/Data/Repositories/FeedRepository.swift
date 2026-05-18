import Foundation
import Networking
import Common
import SplickDomain

public final class FeedRepository: FeedRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchFeed(page: Int, limit: Int) async throws -> [Post] {
        let dtos: [PostDTO] = try await apiClient.request(FeedEndpoint.feed(page: page, limit: limit))
        return dtos.map(FeedMapper.toPost)
    }

    public func fetchPost(id: UUID) async throws -> Post {
        let dto: PostDTO = try await apiClient.request(FeedEndpoint.post(id: id))
        return FeedMapper.toPost(dto)
    }

    public func addReaction(postId: UUID, emoji: String) async throws -> Reaction {
        let requestDTO = CreateReactionRequestDTO(emoji: emoji)
        let dto: ReactionDTO = try await apiClient.request(
            FeedEndpoint.addReaction(postId: postId, requestDTO)
        )
        return FeedMapper.toReaction(dto)
    }

    public func removeReaction(postId: UUID, reactionId: UUID) async throws {
        try await apiClient.request(FeedEndpoint.removeReaction(postId: postId, reactionId: reactionId))
    }

    public func createPost(_ input: CreatePostInput) async throws -> Post {
        guard let imageData = input.imageData else {
            throw NetworkError.unknown("Missing image data")
        }
        let dto: PostDTO = try await apiClient.upload(
            FeedEndpoint.feed(page: 0, limit: 0),
            data: imageData,
            mimeType: "image/jpeg"
        )
        return FeedMapper.toPost(dto)
    }

    public func deletePost(id: UUID) async throws {
        try await apiClient.request(FeedEndpoint.deletePost(id: id))
    }
}
