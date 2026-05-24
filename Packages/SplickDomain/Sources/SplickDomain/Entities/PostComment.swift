import Foundation

public enum CommentAttachmentKind: String, Codable, Equatable, Sendable {
    case image
    case video
    case file
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

public struct PostComment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let author: UserSummary
    public let text: String?
    public let attachments: [CommentAttachment]
    public let parentCommentId: UUID?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        author: UserSummary,
        text: String? = nil,
        attachments: [CommentAttachment] = [],
        parentCommentId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.attachments = attachments
        self.parentCommentId = parentCommentId
        self.createdAt = createdAt
    }
}

public extension Array where Element == PostComment {
    /// Top-level comments only.
    var topLevel: [PostComment] {
        filter { $0.parentCommentId == nil }
    }

    func children(of parentId: UUID) -> [PostComment] {
        filter { $0.parentCommentId == parentId }
    }

    func replies(to parentId: UUID) -> [PostComment] {
        children(of: parentId)
    }

    func totalCommentCount() -> Int {
        count
    }
}
