import Foundation

public enum PostMediaType: String, Codable, Equatable, Sendable {
    case image
    case video
}

public enum PostFeedKind: String, Codable, Equatable, Sendable {
    case checkIn
    case shareBill
}

public enum PaymentSplitStatus: String, Codable, Equatable, Sendable {
    case unpaid = "UNPAID"
    case pendingApproval = "PENDING_APPROVAL"
    case paid = "PAID"
}

public struct PostBillSplitLine: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let user: UserSummary
    public let amount: Decimal
    public let isPaid: Bool
    public let paymentStatus: PaymentSplitStatus
    public let latestEvidenceCommentId: UUID?
    public let lastRejectedAt: Date?
    /// Total payment reminders (manual + auto) for this split.
    public let reminderCount: Int

    public init(
        id: UUID = UUID(),
        user: UserSummary,
        amount: Decimal,
        isPaid: Bool = false,
        paymentStatus: PaymentSplitStatus? = nil,
        latestEvidenceCommentId: UUID? = nil,
        lastRejectedAt: Date? = nil,
        reminderCount: Int = 0
    ) {
        self.id = id
        self.user = user
        self.amount = amount
        self.isPaid = isPaid
        if let paymentStatus {
            self.paymentStatus = paymentStatus
        } else {
            self.paymentStatus = isPaid ? .paid : .unpaid
        }
        self.latestEvidenceCommentId = latestEvidenceCommentId
        self.lastRejectedAt = lastRejectedAt
        self.reminderCount = max(reminderCount, 0)
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
    /// Ordered gallery from API (`mediaItems`); legacy single-media fields mirror the first item.
    public let mediaItems: [PostMediaItem]
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
    public let audience: PostAudience
    public let groupId: UUID?
    public let companionGroupName: String?
    public let createdAt: Date
    /// Server total reaction rows (list omits the raw `reactions` array).
    public let reactionCount: Int
    /// Distinct users who reacted.
    public let reactorCount: Int
    /// Top reactors from the list API (actor pinned). Empty when `reactions` is the source of truth.
    public let reactionPreviewSummaries: [UserReactionSummary]

    /// Monotonic revision for O(1) `Equatable` — bumps on every `updating()` / explicit stamp.
    public let version: UInt64
    /// Precomputed carousel items (sorted once at init).
    public let displayMediaItems: [PostMediaItem]
    /// Precomputed non-deleted comment count.
    public let commentCount: Int

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
        companionGroupName: String? = nil,
        createdAt: Date = .now,
        mediaType: PostMediaType = .image,
        videoURL: URL? = nil,
        videoDurationSeconds: Int? = nil,
        mediaItems: [PostMediaItem] = [],
        companions: [UserSummary] = [],
        feedKind: PostFeedKind = .checkIn,
        checkInPlace: String? = nil,
        billSplit: PostBillSplit? = nil,
        viewCount: Int = 0,
        viewers: [UserSummary] = [],
        audience: PostAudience = .friends,
        version: UInt64 = 0,
        reactionCount: Int? = nil,
        reactorCount: Int? = nil,
        reactionPreviewSummaries: [UserReactionSummary] = []
    ) {
        self.id = id
        self.author = author
        self.mediaItems = mediaItems
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
        self.audience = audience
        self.groupId = groupId
        self.companionGroupName = companionGroupName
        self.createdAt = createdAt
        self.version = version
        self.reactionCount = reactionCount ?? reactions.count
        self.reactorCount = reactorCount ?? Set(reactions.map(\.userId)).count
        self.reactionPreviewSummaries = reactionPreviewSummaries
        self.displayMediaItems = Self.makeDisplayMediaItems(
            id: id,
            mediaItems: mediaItems,
            mediaType: mediaType,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            videoURL: videoURL,
            videoDurationSeconds: videoDurationSeconds
        )
        self.commentCount = comments.reduce(0) { count, comment in
            comment.isDeleted ? count : count + 1
        }
    }

    /// O(1) equality for SwiftUI `.equatable()` diffs — relies on `version` stamps from `updating()` / feed merge.
    public static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }

    public var canDelete: Bool { viewCount == 0 }

    public var hasMultipleMedia: Bool {
        displayMediaItems.count > 1
    }

    public func updating(
        reactions: [Reaction]? = nil,
        comments: [PostComment]? = nil,
        viewCount: Int? = nil,
        viewers: [UserSummary]? = nil,
        mediaItems: [PostMediaItem]? = nil,
        billSplit: PostBillSplit? = nil,
        companionGroupName: String? = nil,
        reactionCount: Int? = nil,
        reactorCount: Int? = nil,
        reactionPreviewSummaries: [UserReactionSummary]? = nil
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
            companionGroupName: companionGroupName ?? self.companionGroupName,
            createdAt: createdAt,
            mediaType: mediaType,
            videoURL: videoURL,
            videoDurationSeconds: videoDurationSeconds,
            mediaItems: mediaItems ?? self.mediaItems,
            companions: companions,
            feedKind: feedKind,
            checkInPlace: checkInPlace,
            billSplit: billSplit ?? self.billSplit,
            viewCount: viewCount ?? self.viewCount,
            viewers: viewers ?? self.viewers,
            audience: audience,
            version: version &+ 1,
            reactionCount: reactionCount ?? self.reactionCount,
            reactorCount: reactorCount ?? self.reactorCount,
            reactionPreviewSummaries: reactionPreviewSummaries ?? self.reactionPreviewSummaries
        )
    }

    /// Returns a copy with an explicit version (used when merging network posts against local state).
    public func withVersion(_ version: UInt64) -> Post {
        guard version != self.version else { return self }
        return Post(
            id: id,
            author: author,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            caption: caption,
            reactions: reactions,
            comments: comments,
            groupId: groupId,
            companionGroupName: companionGroupName,
            createdAt: createdAt,
            mediaType: mediaType,
            videoURL: videoURL,
            videoDurationSeconds: videoDurationSeconds,
            mediaItems: mediaItems,
            companions: companions,
            feedKind: feedKind,
            checkInPlace: checkInPlace,
            billSplit: billSplit,
            viewCount: viewCount,
            viewers: viewers,
            audience: audience,
            version: version,
            reactionCount: reactionCount,
            reactorCount: reactorCount,
            reactionPreviewSummaries: reactionPreviewSummaries
        )
    }

    /// Deep content compare for feed-card UI (used at merge time, not during scroll diffs).
    public func hasSameCardContent(as other: Post) -> Bool {
        reactions == other.reactions
            && comments == other.comments
            && viewCount == other.viewCount
            && viewers == other.viewers
            && billSplit == other.billSplit
            && companionGroupName == other.companionGroupName
            && mediaItems == other.mediaItems
            && caption == other.caption
            && author == other.author
            && imageURL == other.imageURL
            && thumbnailURL == other.thumbnailURL
            && videoURL == other.videoURL
            && videoDurationSeconds == other.videoDurationSeconds
            && mediaType == other.mediaType
            && companions == other.companions
            && feedKind == other.feedKind
            && checkInPlace == other.checkInPlace
            && audience == other.audience
            && groupId == other.groupId
            && reactionCount == other.reactionCount
            && reactorCount == other.reactorCount
            && reactionPreviewSummaries == other.reactionPreviewSummaries
    }

    /// Preserves local version when content is unchanged; otherwise bumps so Equatable detects the change.
    public func ensuringVersion(relativeTo previous: Post?) -> Post {
        guard let previous, previous.id == id else { return self }
        if hasSameCardContent(as: previous) {
            return withVersion(previous.version)
        }
        return withVersion(previous.version &+ 1)
    }

    /// Bumps reminder counts for unpaid targets after a successful remind action.
    public func incrementingBillReminders(for userIds: Set<UUID>) -> Post {
        guard let bill = billSplit, !userIds.isEmpty else { return self }
        let updatedSplits = bill.splits.map { line -> PostBillSplitLine in
            guard !line.isPaid, userIds.contains(line.user.id) else { return line }
            return PostBillSplitLine(
                id: line.id,
                user: line.user,
                amount: line.amount,
                isPaid: line.isPaid,
                paymentStatus: line.paymentStatus,
                latestEvidenceCommentId: line.latestEvidenceCommentId,
                lastRejectedAt: line.lastRejectedAt,
                reminderCount: line.reminderCount + 1
            )
        }
        return updating(
            billSplit: PostBillSplit(
                totalAmount: bill.totalAmount,
                currency: bill.currency,
                splits: updatedSplits
            )
        )
    }

    /// Keeps the higher reminder count per split when merging a local optimistic update.
    public func mergingBillReminderCounts(from other: Post) -> Post {
        guard let bill = billSplit, let otherBill = other.billSplit else { return self }
        let otherCounts = Dictionary(
            uniqueKeysWithValues: otherBill.splits.map { ($0.id, $0.reminderCount) }
        )
        let mergedSplits = bill.splits.map { line -> PostBillSplitLine in
            let mergedCount = max(line.reminderCount, otherCounts[line.id] ?? 0)
            guard mergedCount != line.reminderCount else { return line }
            return PostBillSplitLine(
                id: line.id,
                user: line.user,
                amount: line.amount,
                isPaid: line.isPaid,
                paymentStatus: line.paymentStatus,
                latestEvidenceCommentId: line.latestEvidenceCommentId,
                lastRejectedAt: line.lastRejectedAt,
                reminderCount: mergedCount
            )
        }
        return updating(
            billSplit: PostBillSplit(
                totalAmount: bill.totalAmount,
                currency: bill.currency,
                splits: mergedSplits
            )
        )
    }

    public var knownUsers: [UUID: UserSummary] {
        var map = [author.id: author]
        companions.forEach { map[$0.id] = $0 }
        billSplit?.splits.forEach { map[$0.user.id] = $0.user }
        comments.forEach { map[$0.author.id] = $0.author }
        viewers.forEach { map[$0.id] = $0 }
        reactionPreviewSummaries.forEach { map[$0.userId] = $0.user }
        return map
    }

    private static func makeDisplayMediaItems(
        id: UUID,
        mediaItems: [PostMediaItem],
        mediaType: PostMediaType,
        imageURL: URL,
        thumbnailURL: URL?,
        videoURL: URL?,
        videoDurationSeconds: Int?
    ) -> [PostMediaItem] {
        if !mediaItems.isEmpty {
            return mediaItems.sorted { $0.sortOrder < $1.sortOrder }
        }
        return [
            PostMediaItem(
                id: id,
                mediaURL: videoURL ?? imageURL,
                thumbnailURL: thumbnailURL,
                mediaType: mediaType,
                durationSeconds: videoDurationSeconds,
                sortOrder: 0
            ),
        ]
    }

    // MARK: - Codable (version / derived fields are not persisted)

    private enum CodingKeys: String, CodingKey {
        case id, author, mediaItems, mediaType, imageURL, thumbnailURL, videoURL
        case videoDurationSeconds, caption, reactions, comments, companions
        case feedKind, checkInPlace, billSplit, viewCount, viewers, audience
        case groupId, companionGroupName, createdAt
        case reactionCount, reactorCount, reactionPreviewSummaries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let author = try container.decode(UserSummary.self, forKey: .author)
        let mediaItems = try container.decodeIfPresent([PostMediaItem].self, forKey: .mediaItems) ?? []
        let mediaType = try container.decodeIfPresent(PostMediaType.self, forKey: .mediaType) ?? .image
        let imageURL = try container.decode(URL.self, forKey: .imageURL)
        let thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        let videoURL = try container.decodeIfPresent(URL.self, forKey: .videoURL)
        let videoDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .videoDurationSeconds)
        let caption = try container.decodeIfPresent(String.self, forKey: .caption)
        let reactions = try container.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
        let comments = try container.decodeIfPresent([PostComment].self, forKey: .comments) ?? []
        let companions = try container.decodeIfPresent([UserSummary].self, forKey: .companions) ?? []
        let feedKind = try container.decodeIfPresent(PostFeedKind.self, forKey: .feedKind) ?? .checkIn
        let checkInPlace = try container.decodeIfPresent(String.self, forKey: .checkInPlace)
        let billSplit = try container.decodeIfPresent(PostBillSplit.self, forKey: .billSplit)
        let viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        let viewers = try container.decodeIfPresent([UserSummary].self, forKey: .viewers) ?? []
        let audience = try container.decodeIfPresent(PostAudience.self, forKey: .audience) ?? .friends
        let groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
        let companionGroupName = try container.decodeIfPresent(String.self, forKey: .companionGroupName)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now

        self.init(
            id: id,
            author: author,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            caption: caption,
            reactions: reactions,
            comments: comments,
            groupId: groupId,
            companionGroupName: companionGroupName,
            createdAt: createdAt,
            mediaType: mediaType,
            videoURL: videoURL,
            videoDurationSeconds: videoDurationSeconds,
            mediaItems: mediaItems,
            companions: companions,
            feedKind: feedKind,
            checkInPlace: checkInPlace,
            billSplit: billSplit,
            viewCount: viewCount,
            viewers: viewers,
            audience: audience,
            version: 0,
            reactionCount: try container.decodeIfPresent(Int.self, forKey: .reactionCount),
            reactorCount: try container.decodeIfPresent(Int.self, forKey: .reactorCount),
            reactionPreviewSummaries: try container.decodeIfPresent(
                [UserReactionSummary].self, forKey: .reactionPreviewSummaries
            ) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(author, forKey: .author)
        try container.encode(mediaItems, forKey: .mediaItems)
        try container.encode(mediaType, forKey: .mediaType)
        try container.encode(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encodeIfPresent(videoURL, forKey: .videoURL)
        try container.encodeIfPresent(videoDurationSeconds, forKey: .videoDurationSeconds)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encode(reactions, forKey: .reactions)
        try container.encode(comments, forKey: .comments)
        try container.encode(companions, forKey: .companions)
        try container.encode(feedKind, forKey: .feedKind)
        try container.encodeIfPresent(checkInPlace, forKey: .checkInPlace)
        try container.encodeIfPresent(billSplit, forKey: .billSplit)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(viewers, forKey: .viewers)
        try container.encode(audience, forKey: .audience)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encodeIfPresent(companionGroupName, forKey: .companionGroupName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(reactionCount, forKey: .reactionCount)
        try container.encode(reactorCount, forKey: .reactorCount)
        try container.encode(reactionPreviewSummaries, forKey: .reactionPreviewSummaries)
    }
}

public struct Reaction: Codable, Equatable, Hashable, Sendable, Identifiable {
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

public struct UserEmojiCount: Equatable, Sendable, Codable {
    public let emoji: String
    public let count: Int

    public init(emoji: String, count: Int) {
        self.emoji = emoji
        self.count = count
    }
}

/// Reactions grouped by user, e.g. User A: ❤️×5 😂×10
public struct UserReactionSummary: Identifiable, Equatable, Sendable, Codable {
    public let userId: UUID
    public let user: UserSummary
    public let emojiCounts: [UserEmojiCount]

    public var id: UUID { userId }

    public init(userId: UUID, user: UserSummary, emojiCounts: [UserEmojiCount]) {
        self.userId = userId
        self.user = user
        self.emojiCounts = emojiCounts
    }

    public var totalCount: Int {
        emojiCounts.reduce(0) { $0 + $1.count }
    }

    public var compactLabel: String {
        emojiCounts.map { "\($0.emoji)×\($0.count)" }.joined(separator: " ")
    }
}

public struct PostReactionList: Equatable, Sendable {
    public let reactionCount: Int
    public let reactorCount: Int
    public let items: [UserReactionSummary]

    public init(reactionCount: Int, reactorCount: Int, items: [UserReactionSummary]) {
        self.reactionCount = reactionCount
        self.reactorCount = reactorCount
        self.items = items
    }
}

public extension Post {
    func userReactionSummaries() -> [UserReactionSummary] {
        if reactions.isEmpty {
            return reactionPreviewSummaries
        }
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
        let others = max(0, reactorCount - top.count)
        return (top, others)
    }

    func applyingReaction(emoji: String, from user: UserSummary, id: UUID) -> Post {
        let newReactions = reactions.isEmpty
            ? reactions
            : reactions + [Reaction(id: id, emoji: emoji, userId: user.id)]
        var preview = userReactionSummaries()
        let wasNewUser = !preview.contains { $0.userId == user.id }
        if let index = preview.firstIndex(where: { $0.userId == user.id }) {
            let existing = preview[index]
            var counts = existing.emojiCounts
            if let emojiIndex = counts.firstIndex(where: { $0.emoji == emoji }) {
                counts[emojiIndex] = UserEmojiCount(emoji: emoji, count: counts[emojiIndex].count + 1)
            } else {
                counts.append(UserEmojiCount(emoji: emoji, count: 1))
            }
            counts.sort { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.emoji < rhs.emoji
            }
            preview[index] = UserReactionSummary(userId: user.id, user: user, emojiCounts: counts)
            let mine = preview.remove(at: index)
            preview.insert(mine, at: 0)
        } else {
            preview.insert(
                UserReactionSummary(
                    userId: user.id,
                    user: user,
                    emojiCounts: [UserEmojiCount(emoji: emoji, count: 1)]
                ),
                at: 0
            )
        }
        if preview.count > 3 {
            preview = Array(preview.prefix(3))
        }
        return updating(
            reactions: newReactions,
            reactionCount: reactionCount + 1,
            reactorCount: reactorCount + (wasNewUser ? 1 : 0),
            reactionPreviewSummaries: preview
        )
    }

    func revertingReaction(emoji: String, userId: UUID, reactionId: UUID) -> Post {
        let newReactions = reactions.filter { $0.id != reactionId }
        var preview = userReactionSummaries()
        var nextReactorCount = reactorCount
        if let index = preview.firstIndex(where: { $0.userId == userId }) {
            let existing = preview[index]
            var counts = existing.emojiCounts
            if let emojiIndex = counts.firstIndex(where: { $0.emoji == emoji }) {
                let next = counts[emojiIndex].count - 1
                if next <= 0 {
                    counts.remove(at: emojiIndex)
                } else {
                    counts[emojiIndex] = UserEmojiCount(emoji: emoji, count: next)
                }
            }
            if counts.isEmpty {
                preview.remove(at: index)
                nextReactorCount = max(0, reactorCount - 1)
            } else {
                preview[index] = UserReactionSummary(
                    userId: existing.userId,
                    user: existing.user,
                    emojiCounts: counts
                )
            }
        }
        return updating(
            reactions: newReactions,
            reactionCount: max(0, reactionCount - 1),
            reactorCount: nextReactorCount,
            reactionPreviewSummaries: preview
        )
    }

    /// e.g. "Linh Pham" or "Linh Pham và +50 người khác"
    func companionsSummaryText(maxNamed: Int = 1) -> String? {
        if let companionGroupName, !companionGroupName.isEmpty {
            return companionGroupName
        }
        guard !companions.isEmpty else { return nil }
        if companions.count <= maxNamed {
            return companions.map(\.displayName).joined(separator: ", ")
        }
        let first = companions.prefix(maxNamed).map(\.displayName).joined(separator: ", ")
        let others = companions.count - maxNamed
        return "\(first) và +\(others) người khác"
    }

    /// Split line for the given user in a share-bill post.
    func billSplitLine(for userId: UUID) -> PostBillSplitLine? {
        billSplit?.splits.first { $0.user.id == userId }
    }
}
