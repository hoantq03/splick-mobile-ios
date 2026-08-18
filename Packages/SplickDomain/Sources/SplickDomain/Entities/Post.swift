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
    /// Raw reaction rows (empty on compact list/detail payloads). Prefer `reactionPreview` + counts.
    public let reactions: [Reaction]
    /// Total reaction rows on the post (may exceed `reactions.count` on compact payloads).
    public let reactionCount: Int
    /// Distinct users who reacted.
    public let reactorCount: Int
    /// Top reactors from the API (at most 3). Empty means "derive from `reactions`" when present.
    public let reactionPreview: [UserReactionSummary]
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

    /// Monotonic revision for O(1) `Equatable` — bumps on every `updating()` / explicit stamp.
    public let version: UInt64
    /// Precomputed carousel items (sorted once at init).
    public let displayMediaItems: [PostMediaItem]
    /// Total comments on the post (may exceed embedded `comments` preview length).
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
        reactionCount: Int? = nil,
        reactorCount: Int? = nil,
        reactionPreview: [UserReactionSummary]? = nil,
        comments: [PostComment] = [],
        commentCount: Int? = nil,
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
        version: UInt64 = 0
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
        self.reactionCount = reactionCount ?? reactions.count
        self.reactorCount = reactorCount ?? Set(reactions.map(\.userId)).count
        self.reactionPreview = reactionPreview ?? []
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
        self.displayMediaItems = Self.makeDisplayMediaItems(
            id: id,
            mediaItems: mediaItems,
            mediaType: mediaType,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            videoURL: videoURL,
            videoDurationSeconds: videoDurationSeconds
        )
        let derivedCommentCount = comments.reduce(0) { count, comment in
            comment.isDeleted ? count : count + 1
        }
        self.commentCount = commentCount ?? derivedCommentCount
    }

    /// O(1) equality for SwiftUI `.equatable()` diffs — relies on `version` stamps from `updating()` / feed merge.
    public static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }

    /// Author-only delete is enforced in the UI. Backend also blocks share-bill posts
    /// that already have a payment-evidence comment (`POST_HAS_EVIDENCE`).
    public var canDelete: Bool {
        guard feedKind == .shareBill else { return true }
        if comments.contains(where: { $0.isEvidence && !$0.isDeleted }) { return false }
        if billSplit?.splits.contains(where: { $0.latestEvidenceCommentId != nil }) == true {
            return false
        }
        return true
    }

    public var hasMultipleMedia: Bool {
        displayMediaItems.count > 1
    }

    public func updating(
        reactions: [Reaction]? = nil,
        reactionCount: Int? = nil,
        reactorCount: Int? = nil,
        reactionPreview: [UserReactionSummary]? = nil,
        comments: [PostComment]? = nil,
        commentCount: Int? = nil,
        viewCount: Int? = nil,
        viewers: [UserSummary]? = nil,
        mediaItems: [PostMediaItem]? = nil,
        billSplit: PostBillSplit? = nil,
        companionGroupName: String? = nil
    ) -> Post {
        let nextReactions = reactions ?? self.reactions
        let nextComments = comments ?? self.comments
        let nextCommentCount: Int
        if let commentCount {
            nextCommentCount = commentCount
        } else if comments != nil {
            nextCommentCount = nextComments.reduce(0) { count, comment in
                comment.isDeleted ? count : count + 1
            }
        } else {
            nextCommentCount = self.commentCount
        }
        return Post(
            id: id,
            author: author,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            caption: caption,
            reactions: nextReactions,
            reactionCount: reactionCount ?? self.reactionCount,
            reactorCount: reactorCount ?? self.reactorCount,
            reactionPreview: reactionPreview ?? self.reactionPreview,
            comments: nextComments,
            commentCount: nextCommentCount,
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
            version: version &+ 1
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
            reactionCount: reactionCount,
            reactorCount: reactorCount,
            reactionPreview: reactionPreview,
            comments: comments,
            commentCount: commentCount,
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
            version: version
        )
    }

    /// Deep content compare for feed-card UI (used at merge time, not during scroll diffs).
    public func hasSameCardContent(as other: Post) -> Bool {
        reactions == other.reactions
            && reactionCount == other.reactionCount
            && reactorCount == other.reactorCount
            && reactionPreview == other.reactionPreview
            && comments == other.comments
            && commentCount == other.commentCount
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
        reactionPreview.forEach { map[$0.user.id] = $0.user }
        return map
    }

    /// Username (lowercased) → display name for rendering `@mentions` while storage stays `@username`.
    public var mentionDisplayNamesByUsername: [String: String] {
        var map: [String: String] = [:]
        for user in knownUsers.values {
            let key = user.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let name = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            map[key] = name.isEmpty ? user.username : name
        }
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
        case videoDurationSeconds, caption, reactions, reactionCount, reactorCount
        case reactionPreview, comments, commentCount, companions
        case feedKind, checkInPlace, billSplit, viewCount, viewers, audience
        case groupId, companionGroupName, createdAt
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
        let reactionCount = try container.decodeIfPresent(Int.self, forKey: .reactionCount)
        let reactorCount = try container.decodeIfPresent(Int.self, forKey: .reactorCount)
        let reactionPreview = try container.decodeIfPresent([UserReactionSummary].self, forKey: .reactionPreview)
        let comments = try container.decodeIfPresent([PostComment].self, forKey: .comments) ?? []
        let commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
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
            reactionCount: reactionCount,
            reactorCount: reactorCount,
            reactionPreview: reactionPreview,
            comments: comments,
            commentCount: commentCount,
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
            version: 0
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
        try container.encode(reactionCount, forKey: .reactionCount)
        try container.encode(reactorCount, forKey: .reactorCount)
        try container.encode(reactionPreview, forKey: .reactionPreview)
        try container.encode(comments, forKey: .comments)
        try container.encode(commentCount, forKey: .commentCount)
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

public struct UserEmojiCount: Codable, Equatable, Sendable {
    public let emoji: String
    public let count: Int

    public init(emoji: String, count: Int) {
        self.emoji = emoji
        self.count = count
    }
}

/// Reactions grouped by user, e.g. User A: ❤️×5 😂×10
public struct UserReactionSummary: Identifiable, Codable, Equatable, Sendable {
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

    public init(userId: UUID, user: UserSummary, emojiCounts: [UserEmojiCount]) {
        self.userId = userId
        self.user = user
        self.emojiCounts = emojiCounts
    }

    public init(user: UserSummary, emojiCounts: [UserEmojiCount]) {
        self.init(userId: user.id, user: user, emojiCounts: emojiCounts)
    }
}

public extension Post {
    /// Prefer server `reactionPreview` when present; otherwise aggregate from raw `reactions`.
    func userReactionSummaries() -> [UserReactionSummary] {
        if !reactionPreview.isEmpty && reactions.isEmpty {
            return reactionPreview
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
                    ?? reactionPreview.first(where: { $0.userId == userId })?.user
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
        if !self.reactionPreview.isEmpty {
            let top = Array(self.reactionPreview.prefix(topLimit))
            let others = max(0, reactorCount - top.count)
            return (top, others)
        }
        let all = userReactionSummaries()
        let top = Array(all.prefix(topLimit))
        let others = max(0, (reactorCount > 0 ? reactorCount : all.count) - topLimit)
        return (top, others)
    }

    /// Applies an optimistic reaction from the current user without requiring a full row list.
    func applyingOptimisticReaction(
        emoji: String,
        reactionId: UUID,
        user: UserSummary
    ) -> Post {
        let alreadyReactor = reactionPreview.contains { $0.userId == user.id }
            || reactions.contains { $0.userId == user.id }
        let nextReactionCount = reactionCount + 1
        let nextReactorCount = alreadyReactor ? reactorCount : reactorCount + 1

        var preview = reactionPreview
        if preview.isEmpty, !reactions.isEmpty {
            preview = userReactionSummaries()
        }

        if let index = preview.firstIndex(where: { $0.userId == user.id }) {
            var counts = preview[index].emojiCounts
            if let emojiIndex = counts.firstIndex(where: { $0.emoji == emoji }) {
                counts[emojiIndex] = UserEmojiCount(emoji: emoji, count: counts[emojiIndex].count + 1)
            } else {
                counts.append(UserEmojiCount(emoji: emoji, count: 1))
            }
            counts.sort { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.emoji < rhs.emoji
            }
            preview[index] = UserReactionSummary(user: user, emojiCounts: counts)
        } else {
            preview.insert(
                UserReactionSummary(user: user, emojiCounts: [UserEmojiCount(emoji: emoji, count: 1)]),
                at: 0
            )
        }

        // Pin actor first, then by total count, then userId — matches backend ordering.
        let actorId = user.id
        preview.sort { lhs, rhs in
            if lhs.userId == actorId { return true }
            if rhs.userId == actorId { return false }
            if lhs.totalCount != rhs.totalCount { return lhs.totalCount > rhs.totalCount }
            return lhs.userId.uuidString < rhs.userId.uuidString
        }
        if preview.count > 3 {
            preview = Array(preview.prefix(3))
        }

        var nextReactions = reactions
        if !reactions.isEmpty || reactionPreview.isEmpty {
            nextReactions = reactions + [
                Reaction(id: reactionId, emoji: emoji, userId: user.id),
            ]
        }

        return updating(
            reactions: nextReactions,
            reactionCount: nextReactionCount,
            reactorCount: nextReactorCount,
            reactionPreview: preview
        )
    }

    /// Rolls back a failed optimistic reaction.
    func removingOptimisticReaction(reactionId: UUID, emoji: String, userId: UUID) -> Post {
        let nextReactions = reactions.filter { $0.id != reactionId }
        var preview = reactionPreview
        if let index = preview.firstIndex(where: { $0.userId == userId }) {
            var counts = preview[index].emojiCounts
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
            } else {
                preview[index] = UserReactionSummary(
                    user: preview[index].user,
                    emojiCounts: counts
                )
            }
        }
        let stillReactor = preview.contains { $0.userId == userId }
            || nextReactions.contains { $0.userId == userId }
        return updating(
            reactions: nextReactions,
            reactionCount: max(0, reactionCount - 1),
            reactorCount: stillReactor ? reactorCount : max(0, reactorCount - 1),
            reactionPreview: preview
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
