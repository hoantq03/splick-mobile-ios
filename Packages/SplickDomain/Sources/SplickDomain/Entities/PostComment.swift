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
    }

    public var isEvidence: Bool { commentType == .evidence }

    public var isDeleted: Bool { deletedAt != nil }

    public var isEdited: Bool {
        guard let updatedAt, !isDeleted else { return false }
        return updatedAt.timeIntervalSince(createdAt) > 1
    }

    /// Text shown in the thread (tombstone when soft-deleted).
    public var displayText: String? {
        if isDeleted { return nil }
        return text
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
