import Foundation
import Common
import SplickDomain
import FeatureSocialFeed

public actor FakeFeedRepository: FeedRepositoryProtocol {
    private var posts: [Post] = []
    private let logger: StateLogger

    private static let sampleVideoURL = URL(
        string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    )!

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        let linh = UserSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            username: "linhpham",
            displayName: "Linh Pham",
            avatarURL: nil
        )
        let duc = UserSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            username: "ducnguyen",
            displayName: "Duc Nguyen",
            avatarURL: nil
        )
        let minh = UserSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            username: "minhthu",
            displayName: "Minh Thu",
            avatarURL: nil
        )
        let nam = UserSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            username: "namtran",
            displayName: "Nam Tran",
            avatarURL: nil
        )

        let friends = (0..<52).map { i in
            UserSummary(
                id: UUID(),
                username: "friend\(i)",
                displayName: "Friend \(i + 1)",
                avatarURL: nil
            )
        }

        func repeated(_ userId: UUID, emoji: String, count: Int) -> [Reaction] {
            (0..<count).map { _ in Reaction(id: UUID(), emoji: emoji, userId: userId) }
        }

        func reactionsFrom(
            _ entries: [(userId: UUID, emoji: String, count: Int)]
        ) -> [Reaction] {
            entries.flatMap { repeated($0.userId, emoji: $0.emoji, count: $0.count) }
        }

        func paginatedComments(authors: [UserSummary]) -> [PostComment] {
            var items: [PostComment] = []
            for index in 0..<28 {
                let author = authors[index % authors.count]
                let parentId = UUID()
                items.append(
                    PostComment(
                        id: parentId,
                        author: author,
                        text: "Bình luận #\(index + 1) — trải nghiệm hay quá!",
                        attachments: index % 7 == 0
                            ? [CommentAttachment(kind: .image, url: URL(string: "https://picsum.photos/seed/c\(index)/120/90")!, sizeBytes: 600_000)]
                            : []
                    )
                )
                if index % 4 == 0 {
                    items.append(
                        PostComment(
                            author: authors[(index + 1) % authors.count],
                            text: "Đồng ý với @\(author.username)!",
                            parentCommentId: parentId
                        )
                    )
                }
            }
            return items
        }

        let viewerSample = [nam, duc, minh, linh] + Array(friends.prefix(9))

        posts = [
            Post(
                id: UUID(),
                author: linh,
                imageURL: URL(string: "https://picsum.photos/seed/feed1/400/500")!,
                caption: "Korean BBQ với hội 🍖",
                reactions: reactionsFrom([
                    (nam.id, "❤️", 5), (nam.id, "😂", 4),
                    (duc.id, "🔥", 3), (linh.id, "👏", 2),
                    (minh.id, "😮", 3), (friends[0].id, "❤️", 2),
                    (friends[1].id, "😂", 2), (friends[2].id, "😍", 2),
                    (friends[3].id, "👏", 1), (friends[4].id, "😢", 1),
                    (friends[5].id, "😡", 1), (friends[6].id, "😮", 2),
                ]),
                comments: paginatedComments(authors: [nam, duc, minh, linh]),
                createdAt: Date().addingTimeInterval(-1800),
                companions: [nam, duc, minh] + Array(friends.prefix(50)),
                feedKind: .shareBill,
                billSplit: PostBillSplit(
                    totalAmount: 450_000,
                    currency: "VND",
                    splits: [
                        PostBillSplitLine(user: linh, amount: 150_000, isPaid: true),
                        PostBillSplitLine(user: nam, amount: 150_000, isPaid: false),
                        PostBillSplitLine(user: duc, amount: 150_000, isPaid: false),
                    ]
                ),
                viewCount: 12,
                viewers: viewerSample
            ),
            Post(
                id: UUID(),
                author: duc,
                imageURL: URL(string: "https://picsum.photos/seed/feed2/400/500")!,
                caption: "Weekend hike",
                reactions: reactionsFrom([
                    (linh.id, "❤️", 4), (minh.id, "😍", 2),
                    (nam.id, "😂", 3), (duc.id, "👏", 2),
                    (friends[7].id, "❤️", 2), (friends[8].id, "😮", 1),
                    (friends[9].id, "🔥", 2), (friends[10].id, "😢", 1),
                ]),
                comments: [
                    PostComment(
                        author: linh,
                        text: "View đẹp quá!",
                        attachments: [
                            CommentAttachment(kind: .video, fileName: "hike-clip.mp4", sizeBytes: 8_000_000)
                        ]
                    )
                ],
                createdAt: Date().addingTimeInterval(-7200),
                mediaType: .video,
                videoURL: Self.sampleVideoURL,
                videoDurationSeconds: 24,
                companions: [linh, minh, nam, duc] + Array(friends[7..<15]),
                feedKind: .checkIn,
                checkInPlace: "Bà Nà Hills, Đà Nẵng",
                viewCount: 0
            ),
            Post(
                id: UUID(),
                author: nam,
                imageURL: URL(string: "https://picsum.photos/seed/feed3/400/400")!,
                caption: nil,
                reactions: [],
                createdAt: Date().addingTimeInterval(-3600),
                companions: [linh],
                feedKind: .checkIn,
                checkInPlace: "The Coffee House · Quận 7",
                viewCount: 0
            ),
            Post(
                id: UUID(),
                author: minh,
                imageURL: URL(string: "https://picsum.photos/seed/feed4/400/600")!,
                caption: "Team lunch",
                reactions: reactionsFrom([
                    (nam.id, "😍", 2), (duc.id, "❤️", 3),
                    (linh.id, "😂", 2), (minh.id, "👏", 1),
                    (friends[11].id, "😮", 2), (friends[12].id, "🔥", 1),
                    (friends[13].id, "😢", 1), (friends[14].id, "😡", 1),
                ]),
                createdAt: Date().addingTimeInterval(-14400),
                companions: [linh, duc, nam, minh] + Array(friends[11..<20]),
                feedKind: .shareBill,
                billSplit: PostBillSplit(
                    totalAmount: 320_000,
                    currency: "VND",
                    splits: [
                        PostBillSplitLine(user: minh, amount: 80_000, isPaid: true),
                        PostBillSplitLine(user: linh, amount: 80_000, isPaid: true),
                        PostBillSplitLine(user: duc, amount: 80_000, isPaid: false),
                        PostBillSplitLine(user: nam, amount: 80_000, isPaid: false),
                    ]
                ),
                viewCount: 3
            ),
        ]

        logger.log("Seeded \(posts.count) rich feed posts")
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

    public func fetchPhotoAlbum(page: Int, limit: Int) async throws -> [AlbumPhoto] {
        logger.log("Fetch photo album: page=\(page), limit=\(limit)")
        try await Task.sleep(for: .milliseconds(350))

        let allPhotos: [AlbumPhoto] = posts.flatMap { post in
            post.displayMediaItems
                .filter { $0.mediaType == .image }
                .map { item in
                    AlbumPhoto(
                        id: item.id,
                        postId: post.id,
                        author: post.author,
                        mediaURL: item.mediaURL,
                        thumbnailURL: item.thumbnailURL,
                        mediaType: item.mediaType,
                        sortOrder: item.sortOrder,
                        createdAt: post.createdAt
                    )
                }
        }
        .sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }

        let start = page * limit
        guard start < allPhotos.count else {
            logger.log("Photo album: no more pages")
            return []
        }

        let end = min(start + limit, allPhotos.count)
        let result = Array(allPhotos[start..<end])
        logger.success("Photo album loaded: \(result.count) photos (page \(page))")
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
        try await Task.sleep(for: .milliseconds(30))

        let reaction = Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: .now)

        if let index = posts.firstIndex(where: { $0.id == postId }) {
            let post = posts[index]
            posts[index] = post.updating(reactions: post.reactions + [reaction])
        }

        logger.success("Reaction added: \(emoji)")
        return reaction
    }

    public func removeReaction(postId: UUID, reactionId: UUID) async throws {
        logger.log("Remove reaction: \(reactionId) from post \(postId)")
        try await Task.sleep(for: .milliseconds(200))
        logger.success("Reaction removed")
    }

    public func createPost(_ input: CreatePostInput) async throws -> Post {
        logger.log("Create post: \(input.mediaItems.count) media items, kind=\(input.feedKind)")
        try await Task.sleep(for: .milliseconds(800))

        let companions = input.companionIds.map { id in
            UserSummary(id: id, username: "friend", displayName: "Friend", avatarURL: nil)
        }

        let mappedMediaItems: [PostMediaItem] = input.mediaItems.enumerated().map { index, item in
            let seed = Int.random(in: 1...999) + index
            let url = URL(string: "https://picsum.photos/seed/new\(seed)/400/500")!
            return PostMediaItem(
                mediaURL: item.mediaType == .video ? Self.sampleVideoURL : url,
                thumbnailURL: url,
                mediaType: item.mediaType,
                durationSeconds: item.videoDurationSeconds,
                sortOrder: index
            )
        }
        let first = mappedMediaItems.first
        let primaryMediaType = first?.mediaType ?? .image
        let post = Post(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "namtran", displayName: "Nam Tran", avatarURL: nil),
            imageURL: first?.thumbnailURL ?? first?.mediaURL ?? URL(string: "https://picsum.photos/400/500")!,
            thumbnailURL: first?.thumbnailURL,
            caption: input.caption,
            reactions: [],
            groupId: input.groupId,
            createdAt: .now,
            mediaType: primaryMediaType,
            videoURL: primaryMediaType == .video ? first?.mediaURL : nil,
            videoDurationSeconds: first?.durationSeconds,
            mediaItems: mappedMediaItems,
            companions: companions,
            feedKind: input.feedKind,
            checkInPlace: input.checkInPlace,
            billSplit: input.billSplit,
            viewCount: 0
        )
        posts.insert(post, at: 0)

        logger.success("Post created: \(post.id)")
        return post
    }

    public func addComment(
        postId: UUID,
        body: String?,
        parentCommentId: UUID?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws {
        logger.log("Add comment to post \(postId): \(body ?? "<attachment-only>")")
        try await Task.sleep(for: .milliseconds(200))
        logger.success("Comment added")
    }

    public func deletePost(id: UUID) async throws {
        logger.log("Delete post: \(id)")
        try await Task.sleep(for: .milliseconds(200))

        guard let index = posts.firstIndex(where: { $0.id == id }) else {
            throw NetworkError.notFound
        }

        guard posts[index].canDelete else {
            throw NetworkError.forbidden
        }

        posts.remove(at: index)
        logger.success("Post deleted")
    }
}
