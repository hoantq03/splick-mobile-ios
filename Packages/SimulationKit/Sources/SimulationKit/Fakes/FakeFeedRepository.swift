import Foundation
import SplickDomain
import FeatureSocialFeed

public actor FakeFeedRepository: FeedRepositoryProtocol {
    private var posts: [Post] = []
    private let logger: StateLogger

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        let authors: [UserSummary] = [
            UserSummary(id: UUID(), username: "linhpham", displayName: "Linh Pham", avatarURL: nil),
            UserSummary(id: UUID(), username: "ducnguyen", displayName: "Duc Nguyen", avatarURL: nil),
            UserSummary(id: UUID(), username: "minhthu", displayName: "Minh Thu", avatarURL: nil),
        ]

        posts = (0..<10).map { i in
            Post(
                id: UUID(),
                author: authors[i % authors.count],
                imageURL: URL(string: "https://picsum.photos/seed/\(i)/400/500")!,
                thumbnailURL: nil,
                caption: ["Coffee vibes ☕", "Weekend mood 🌅", "Squad goals 🔥", nil, "Food time 🍜"][i % 5],
                reactions: i % 3 == 0 ? [Reaction(id: UUID(), emoji: "❤️", userId: UUID())] : [],
                groupId: nil,
                createdAt: Date().addingTimeInterval(Double(-i * 3600))
            )
        }

        logger.log("Seeded \(posts.count) posts")
    }

    public func fetchFeed(page: Int, limit: Int) async throws -> [Post] {
        logger.log("Fetch feed: page=\(page), limit=\(limit)")
        try await Task.sleep(for: .milliseconds(400))

        let start = page * limit
        guard start < posts.count else {
            logger.log("Feed: no more pages")
            return []
        }

        let end = min(start + limit, posts.count)
        let result = Array(posts[start..<end])
        logger.success("Feed loaded: \(result.count) posts (page \(page))")
        return result
    }

    public func fetchPost(id: UUID) async throws -> Post {
        logger.log("Fetch post: \(id)")
        guard let post = posts.first(where: { $0.id == id }) else {
            logger.failure("Post not found: \(id)")
            throw NetworkError.notFound
        }
        return post
    }

    public func addReaction(postId: UUID, emoji: String) async throws -> Reaction {
        logger.log("Add reaction: \(emoji) to post \(postId.uuidString.prefix(8))")
        try await Task.sleep(for: .milliseconds(200))

        let reaction = Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: .now)

        if let index = posts.firstIndex(where: { $0.id == postId }) {
            let post = posts[index]
            posts[index] = Post(
                id: post.id, author: post.author, imageURL: post.imageURL,
                thumbnailURL: post.thumbnailURL, caption: post.caption,
                reactions: post.reactions + [reaction],
                groupId: post.groupId, createdAt: post.createdAt
            )
        }

        logger.success("Reaction added: \(emoji)")
        return reaction
    }

    public func removeReaction(postId: UUID, reactionId: UUID) async throws {
        logger.log("Remove reaction: \(reactionId) from post \(postId)")
        try await Task.sleep(for: .milliseconds(200))
        logger.success("Reaction removed")
    }

    public func createPost(imageData: Data, caption: String?, groupId: UUID?) async throws -> Post {
        logger.log("Create post: \(imageData.count) bytes, caption=\(caption ?? "nil")")
        try await Task.sleep(for: .milliseconds(800))

        let post = Post(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "namtran", displayName: "Nam Tran", avatarURL: nil),
            imageURL: URL(string: "https://picsum.photos/400/500")!,
            caption: caption,
            reactions: [],
            groupId: groupId,
            createdAt: .now
        )
        posts.insert(post, at: 0)

        logger.success("Post created: \(post.id)")
        return post
    }
}
