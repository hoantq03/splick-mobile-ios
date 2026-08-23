import Foundation
import SplickDomain

public struct FriendDisplayNameEntry: Sendable, Equatable {
    public let legalName: String
    public let nickname: String?

    public init(legalName: String, nickname: String?) {
        self.legalName = legalName
        self.nickname = nickname
    }
}

/// In-memory nicknames keyed by friend user id. Populated from the friends directory
/// and applied anywhere API payloads only carry legal profile names.
public actor FriendDisplayNameStore {
    public static let didChangeNotification = Notification.Name("FriendDisplayNameStore.didChange")

    private var entries: [UUID: FriendDisplayNameEntry] = [:]

    public init() {}

    public func clearAll() {
        entries.removeAll()
        notifyChange()
    }

    public func sync(from friends: [UserSummary]) {
        var changed = false
        for friend in friends {
            let legalName = friend.subtitle ?? friend.displayName
            let nickname = friend.subtitle != nil ? friend.displayName : nil
            let next = FriendDisplayNameEntry(legalName: legalName, nickname: nickname)
            if entries[friend.id] != next {
                entries[friend.id] = next
                changed = true
            }
        }
        if changed { notifyChange() }
    }

    public func upsert(from friend: UserSummary) {
        let legalName = friend.subtitle ?? friend.displayName
        let nickname = friend.subtitle != nil ? friend.displayName : nil
        let next = FriendDisplayNameEntry(legalName: legalName, nickname: nickname)
        let changed = entries[friend.id] != next
        entries[friend.id] = next
        if changed { notifyChange() }
    }

    public func upsert(userId: UUID, nickname: String?, legalName: String) {
        let next = FriendDisplayNameEntry(legalName: legalName, nickname: nickname)
        let changed = entries[userId] != next
        entries[userId] = next
        if changed { notifyChange() }
    }

    public func remove(userId: UUID) {
        guard entries.removeValue(forKey: userId) != nil else { return }
        notifyChange()
    }

    public func resolve(_ user: UserSummary) -> UserSummary {
        guard let entry = entries[user.id] else { return user }
        if let nickname = entry.nickname {
            return UserSummary(
                id: user.id,
                username: user.username,
                displayName: nickname,
                subtitle: entry.legalName,
                avatarURL: user.avatarURL,
                viewedAt: user.viewedAt
            )
        }
        return UserSummary(
            id: user.id,
            username: user.username,
            displayName: entry.legalName,
            subtitle: nil,
            avatarURL: user.avatarURL,
            viewedAt: user.viewedAt
        )
    }

    public func resolve(_ users: [UserSummary]) -> [UserSummary] {
        users.map(resolve)
    }

    public func resolve(_ post: Post) -> Post {
        Post(
            id: post.id,
            author: resolve(post.author),
            imageURL: post.imageURL,
            thumbnailURL: post.thumbnailURL,
            caption: post.caption,
            reactions: post.reactions,
            reactionCount: post.reactionCount,
            reactorCount: post.reactorCount,
            reactionPreview: post.reactionPreview.map { summary in
                UserReactionSummary(user: resolve(summary.user), emojiCounts: summary.emojiCounts)
            },
            comments: post.comments.map { comment in
                PostComment(
                    id: comment.id,
                    author: resolve(comment.author),
                    text: comment.text,
                    attachments: comment.attachments,
                    parentCommentId: comment.parentCommentId,
                    createdAt: comment.createdAt,
                    updatedAt: comment.updatedAt,
                    deletedAt: comment.deletedAt,
                    commentType: comment.commentType,
                    evidenceId: comment.evidenceId,
                    splitId: comment.splitId,
                    evidenceStatus: comment.evidenceStatus
                )
            },
            commentCount: post.commentCount,
            groupId: post.groupId,
            companionGroupName: post.companionGroupName,
            createdAt: post.createdAt,
            mediaType: post.mediaType,
            videoURL: post.videoURL,
            videoDurationSeconds: post.videoDurationSeconds,
            mediaItems: post.mediaItems,
            companions: resolve(post.companions),
            feedKind: post.feedKind,
            checkInPlace: post.checkInPlace,
            billSplit: post.billSplit.map { billSplit in
                PostBillSplit(
                    totalAmount: billSplit.totalAmount,
                    currency: billSplit.currency,
                    splits: billSplit.splits.map { line in
                        PostBillSplitLine(
                            id: line.id,
                            user: resolve(line.user),
                            amount: line.amount,
                            isPaid: line.isPaid,
                            paymentStatus: line.paymentStatus,
                            latestEvidenceCommentId: line.latestEvidenceCommentId,
                            lastRejectedAt: line.lastRejectedAt,
                            reminderCount: line.reminderCount
                        )
                    }
                )
            },
            viewCount: post.viewCount,
            viewers: resolve(post.viewers),
            audience: post.audience,
            version: post.version
        )
    }

    public func resolve(_ posts: [Post]) -> [Post] {
        posts.map(resolve)
    }

    public func resolve(_ page: CommentThreadPage) -> CommentThreadPage {
        CommentThreadPage(
            comments: page.comments.map { comment in
                PostComment(
                    id: comment.id,
                    author: resolve(comment.author),
                    text: comment.text,
                    attachments: comment.attachments,
                    parentCommentId: comment.parentCommentId,
                    createdAt: comment.createdAt,
                    updatedAt: comment.updatedAt,
                    deletedAt: comment.deletedAt,
                    commentType: comment.commentType,
                    evidenceId: comment.evidenceId,
                    splitId: comment.splitId,
                    evidenceStatus: comment.evidenceStatus
                )
            },
            page: page.page,
            limit: page.limit,
            hasMore: page.hasMore
        )
    }

    public func resolve(_ reactions: [UserReactionSummary]) -> [UserReactionSummary] {
        reactions.map { summary in
            UserReactionSummary(user: resolve(summary.user), emojiCounts: summary.emojiCounts)
        }
    }

    public func resolve(_ expense: Expense) -> Expense {
        Expense(
            id: expense.id,
            description: expense.description,
            totalAmount: expense.totalAmount,
            currency: expense.currency,
            paidBy: resolve(expense.paidBy),
            splits: expense.splits.map { split in
                ExpenseSplit(
                    id: split.id,
                    user: resolve(split.user),
                    amount: split.amount,
                    isPaid: split.isPaid,
                    paidAt: split.paidAt
                )
            },
            groupId: expense.groupId,
            postId: expense.postId,
            category: expense.category,
            status: expense.status,
            createdAt: expense.createdAt,
            settledAt: expense.settledAt
        )
    }

    public func resolve(_ expenses: [Expense]) -> [Expense] {
        expenses.map(resolve)
    }

    public func resolve(_ summary: DebtSummary) -> DebtSummary {
        DebtSummary(
            user: resolve(summary.user),
            amount: summary.amount,
            currency: summary.currency
        )
    }

    public func resolve(_ summaries: [DebtSummary]) -> [DebtSummary] {
        summaries.map(resolve)
    }

    public func resolve(_ photo: AlbumPhoto) -> AlbumPhoto {
        AlbumPhoto(
            id: photo.id,
            postId: photo.postId,
            author: resolve(photo.author),
            groupId: photo.groupId,
            caption: photo.caption,
            mediaURL: photo.mediaURL,
            thumbnailURL: photo.thumbnailURL,
            mediaType: photo.mediaType,
            sortOrder: photo.sortOrder,
            createdAt: photo.createdAt
        )
    }

    public func resolve(_ photos: [AlbumPhoto]) -> [AlbumPhoto] {
        photos.map(resolve)
    }

    private func notifyChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }
}
