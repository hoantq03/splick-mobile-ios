import Foundation

public enum PostMediaType: String, Codable, Equatable, Sendable {
    case image
    case video
}

public enum PostFeedKind: String, Codable, Equatable, Sendable {
    case checkIn
    case shareBill
}

public struct PostBillSplitLine: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let user: UserSummary
    public let amount: Decimal
    public let isPaid: Bool

    public init(id: UUID = UUID(), user: UserSummary, amount: Decimal, isPaid: Bool = false) {
        self.id = id
        self.user = user
        self.amount = amount
        self.isPaid = isPaid
    }
}

public struct PostBillSplit: Codable, Equatable, Sendable {
    public let totalAmount: Decimal
    public let currency: String
    public let splits: [PostBillSplitLine]

    public init(totalAmount: Decimal, currency: String, splits: [PostBillSplitLine]) {
        self.totalAmount = totalAmount
        self.currency = currency
        self.splits = splits
    }
}

public struct Post: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let author: UserSummary
    public let mediaType: PostMediaType
    public let imageURL: URL
    public let thumbnailURL: URL?
    public let videoURL: URL?
    public let videoDurationSeconds: Int?
    public let caption: String?
    public let reactions: [Reaction]
    public let comments: [PostComment]
    public let companions: [UserSummary]
    public let feedKind: PostFeedKind
    public let checkInPlace: String?
    public let billSplit: PostBillSplit?
    public let viewCount: Int
    public let viewers: [UserSummary]
    public let groupId: UUID?
    public let createdAt: Date

    public var shareURL: URL {
        URL(string: "https://splick.app/post/\(id.uuidString)")!
    }

    public init(
        id: UUID,
        author: UserSummary,
        imageURL: URL,
        thumbnailURL: URL? = nil,
        caption: String? = nil,
        reactions: [Reaction] = [],
        comments: [PostComment] = [],
        groupId: UUID? = nil,
        createdAt: Date = .now,
        mediaType: PostMediaType = .image,
        videoURL: URL? = nil,
        videoDurationSeconds: Int? = nil,
        companions: [UserSummary] = [],
        feedKind: PostFeedKind = .checkIn,
        checkInPlace: String? = nil,
        billSplit: PostBillSplit? = nil,
        viewCount: Int = 0,
        viewers: [UserSummary] = []
    ) {
        self.id = id
        self.author = author
        self.mediaType = mediaType
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.videoURL = videoURL
        self.videoDurationSeconds = videoDurationSeconds
        self.caption = caption
        self.reactions = reactions
        self.comments = comments
        self.companions = companions
        self.feedKind = feedKind
        self.checkInPlace = checkInPlace
        self.billSplit = billSplit
        self.viewCount = viewCount
        self.viewers = viewers
        self.groupId = groupId
        self.createdAt = createdAt
    }

    public var reactionCount: Int { reactions.count }

    public var canDelete: Bool { viewCount == 0 }

    public func updating(
        reactions: [Reaction]? = nil,
        comments: [PostComment]? = nil,
        viewCount: Int? = nil
    ) -> Post {
        Post(
            id: id,
            author: author,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            caption: caption,
            reactions: reactions ?? self.reactions,
            comments: comments ?? self.comments,
            groupId: groupId,
            createdAt: createdAt,
            mediaType: mediaType,
            videoURL: videoURL,
            videoDurationSeconds: videoDurationSeconds,
            companions: companions,
            feedKind: feedKind,
            checkInPlace: checkInPlace,
            billSplit: billSplit,
            viewCount: viewCount ?? self.viewCount,
            viewers: viewers
        )
    }

    public var knownUsers: [UUID: UserSummary] {
        var map = [author.id: author]
        companions.forEach { map[$0.id] = $0 }
        billSplit?.splits.forEach { map[$0.user.id] = $0.user }
        comments.forEach { map[$0.author.id] = $0.author }
        viewers.forEach { map[$0.id] = $0 }
        return map
    }

    public var topLevelCommentCount: Int {
        comments.topLevel.count
    }
}

public struct Reaction: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let emoji: String
    public let userId: UUID
    public let createdAt: Date

    public init(id: UUID, emoji: String, userId: UUID, createdAt: Date = .now) {
        self.id = id
        self.emoji = emoji
        self.userId = userId
        self.createdAt = createdAt
    }
}

public struct UserEmojiCount: Equatable, Sendable {
    public let emoji: String
    public let count: Int
}

/// Reactions grouped by user, e.g. User A: ❤️×5 😂×10
public struct UserReactionSummary: Identifiable, Equatable, Sendable {
    public let userId: UUID
    public let user: UserSummary
    public let emojiCounts: [UserEmojiCount]

    public var id: UUID { userId }

    public var totalCount: Int {
        emojiCounts.reduce(0) { $0 + $1.count }
    }

    public var compactLabel: String {
        emojiCounts.map { "\($0.emoji)×\($0.count)" }.joined(separator: " ")
    }
}

public extension Post {
    func userReactionSummaries() -> [UserReactionSummary] {
        let grouped = Dictionary(grouping: reactions, by: \.userId)

        return grouped
            .map { userId, userReactions in
                let emojiGrouped = Dictionary(grouping: userReactions, by: \.emoji)
                let counts = emojiGrouped
                    .map { UserEmojiCount(emoji: $0.key, count: $0.value.count) }
                    .sorted { lhs, rhs in
                        if lhs.count != rhs.count { return lhs.count > rhs.count }
                        return lhs.emoji < rhs.emoji
                    }

                let user = knownUsers[userId]
                    ?? UserSummary(id: userId, username: "user", displayName: "User")

                return UserReactionSummary(userId: userId, user: user, emojiCounts: counts)
            }
            .sorted { lhs, rhs in
                if lhs.totalCount != rhs.totalCount { return lhs.totalCount > rhs.totalCount }
                return lhs.userId.uuidString < rhs.userId.uuidString
            }
    }

    /// Top reactors and how many additional people reacted (not emoji count).
    func reactionPreview(topLimit: Int = 3) -> (top: [UserReactionSummary], otherPeopleCount: Int) {
        let all = userReactionSummaries()
        let top = Array(all.prefix(topLimit))
        let others = max(0, all.count - topLimit)
        return (top, others)
    }

    /// e.g. "Linh Pham" or "Linh Pham và +50 người khác"
    func companionsSummaryText(maxNamed: Int = 1) -> String? {
        guard !companions.isEmpty else { return nil }
        if companions.count <= maxNamed {
            return companions.map(\.displayName).joined(separator: ", ")
        }
        let first = companions.prefix(maxNamed).map(\.displayName).joined(separator: ", ")
        let others = companions.count - maxNamed
        return "\(first) và +\(others) người khác"
    }
}
