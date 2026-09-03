import Foundation

public enum CommentAttachmentKind: String, Codable, Equatable, Sendable {
    case image
    case video
    case file
    case gif
}

public struct CommentAttachment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: CommentAttachmentKind
    public let url: URL?
    public let fileName: String?
    public let thumbnailURL: URL?
    public let sizeBytes: Int

    public init(
        id: UUID = UUID(),
        kind: CommentAttachmentKind,
        url: URL? = nil,
        fileName: String? = nil,
        thumbnailURL: URL? = nil,
        sizeBytes: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.url = url
        self.fileName = fileName
        self.thumbnailURL = thumbnailURL
        self.sizeBytes = sizeBytes
    }
}

public enum CommentType: String, Codable, Equatable, Sendable {
    case standard = "STANDARD"
    case evidence = "EVIDENCE"
    case evidenceModeration = "EVIDENCE_MODERATION"
}

public enum EvidenceStatus: String, Codable, Equatable, Sendable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
}

public struct PostComment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let author: UserSummary
    public let text: String?
    public let attachments: [CommentAttachment]
    public let parentCommentId: UUID?
    public let createdAt: Date
    public let updatedAt: Date?
    public let deletedAt: Date?
    public let commentType: CommentType
    public let evidenceId: UUID?
    public let splitId: UUID?
    public let evidenceStatus: EvidenceStatus?
    public let mentions: [UserSummary]

    public init(
        id: UUID = UUID(),
        author: UserSummary,
        text: String? = nil,
        attachments: [CommentAttachment] = [],
        parentCommentId: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil,
        commentType: CommentType = .standard,
        evidenceId: UUID? = nil,
        splitId: UUID? = nil,
        evidenceStatus: EvidenceStatus? = nil,
        mentions: [UserSummary]
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.attachments = attachments
        self.parentCommentId = parentCommentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.commentType = commentType
        self.evidenceId = evidenceId
        self.splitId = splitId
        self.evidenceStatus = evidenceStatus
        self.mentions = mentions
    }

    /// Pre-mention ABI for modules compiled against the previous initializer.
    public init(
        id: UUID = UUID(),
        author: UserSummary,
        text: String? = nil,
        attachments: [CommentAttachment] = [],
        parentCommentId: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil,
        commentType: CommentType = .standard,
        evidenceId: UUID? = nil,
        splitId: UUID? = nil,
        evidenceStatus: EvidenceStatus? = nil
    ) {
        self.init(
            id: id,
            author: author,
            text: text,
            attachments: attachments,
            parentCommentId: parentCommentId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            commentType: commentType,
            evidenceId: evidenceId,
            splitId: splitId,
            evidenceStatus: evidenceStatus,
            mentions: []
        )
    }

    public var isEvidence: Bool { commentType == .evidence }

    public var isEvidenceModeration: Bool { commentType == .evidenceModeration }

    public var isDeleted: Bool { deletedAt != nil }

    /// Outcome badge for auto moderation replies (approve / reject).
    public var moderationOutcome: EvidenceStatus? {
        isEvidenceModeration ? evidenceStatus : nil
    }

    public var isEdited: Bool {
        guard let updatedAt, !isDeleted, !isEvidence, !isEvidenceModeration else { return false }
        return updatedAt.timeIntervalSince(createdAt) > 1
    }

    /// Text shown in the thread (tombstone when soft-deleted).
    public var displayText: String? {
        if isDeleted { return nil }
        return text
    }
}

public enum CommentThreadFilter: String, CaseIterable, Equatable, Sendable {
    case comments = "COMMENTS"
    case evidence = "EVIDENCE"
    case all = "ALL"

    public var apiValue: String { rawValue }

    public func includesRoot(_ comment: PostComment) -> Bool {
        guard comment.parentCommentId == nil else { return false }
        switch self {
        case .all: return true
        case .comments: return comment.commentType == .standard
        case .evidence: return comment.commentType == .evidence
        }
    }
}

public struct CommentThreadPage: Equatable, Sendable {
    public let comments: [PostComment]
    public let page: Int
    public let limit: Int
    public let hasMore: Bool

    public init(comments: [PostComment], page: Int, limit: Int, hasMore: Bool) {
        self.comments = comments
        self.page = page
        self.limit = limit
        self.hasMore = hasMore
    }

    /// In-memory paging used by fakes and previews. Matches backend: roots only, plus full subtrees.
    public static func paging(
        from comments: [PostComment],
        page: Int,
        limit: Int,
        filter: CommentThreadFilter
    ) -> CommentThreadPage {
        let roots = comments
            .filter { filter.includesRoot($0) }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        let offset = max(page, 0) * max(limit, 1)
        let hasMore = roots.count > offset + limit
        let pageRoots = Array(roots.dropFirst(offset).prefix(limit))
        var included = Set(pageRoots.map(\.id))
        var grew = true
        while grew {
            grew = false
            for comment in comments where !included.contains(comment.id) {
                if let parentId = comment.parentCommentId, included.contains(parentId) {
                    included.insert(comment.id)
                    grew = true
                }
            }
        }
        let pageComments = comments
            .filter { included.contains($0.id) }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        return CommentThreadPage(comments: pageComments, page: page, limit: limit, hasMore: hasMore)
    }
}

public extension Array where Element == PostComment {
    /// Top-level comments only (legacy flat list).
    var topLevel: [PostComment] {
        filter { $0.parentCommentId == nil }
    }

    func children(of parentId: UUID) -> [PostComment] {
        filter { $0.parentCommentId == parentId }
    }

    func replies(to parentId: UUID) -> [PostComment] {
        children(of: parentId)
    }

    /// All non-deleted comments in the flat list (root + nested).
    var activeCount: Int {
        filter { !$0.isDeleted }.count
    }
}
