import Foundation

public struct CommentSubmissionAttachment: Sendable {
    public let kind: CommentAttachmentKind
    public let data: Data?
    public let remoteURL: URL?
    public let mimeType: String?
    public let fileName: String?
    public let uploadedMediaId: UUID?
    public let uploadedThumbnailURL: URL?
    public let uploadedSizeBytes: Int?

    public init(
        kind: CommentAttachmentKind,
        data: Data,
        mimeType: String,
        fileName: String?
    ) {
        self.kind = kind
        self.data = data
        self.remoteURL = nil
        self.mimeType = mimeType
        self.fileName = fileName
        self.uploadedMediaId = nil
        self.uploadedThumbnailURL = nil
        self.uploadedSizeBytes = nil
    }

    public init(kind: CommentAttachmentKind, remoteURL: URL, fileName: String? = nil) {
        self.kind = kind
        self.data = nil
        self.remoteURL = remoteURL
        self.mimeType = nil
        self.fileName = fileName
        self.uploadedMediaId = nil
        self.uploadedThumbnailURL = nil
        self.uploadedSizeBytes = nil
    }

    public init(
        kind: CommentAttachmentKind,
        uploadedMediaId: UUID,
        url: URL,
        thumbnailURL: URL? = nil,
        sizeBytes: Int,
        fileName: String? = nil
    ) {
        self.kind = kind
        self.data = nil
        self.remoteURL = url
        self.mimeType = nil
        self.fileName = fileName
        self.uploadedMediaId = uploadedMediaId
        self.uploadedThumbnailURL = thumbnailURL
        self.uploadedSizeBytes = sizeBytes
    }

    /// Remote GIF/sticker URL without a prior media-service upload.
    public var isRemoteOnly: Bool {
        remoteURL != nil && data == nil && uploadedMediaId == nil
    }

    /// Image already uploaded to media-service while composing.
    public var isPreUploaded: Bool {
        uploadedMediaId != nil && remoteURL != nil && data == nil
    }
}
