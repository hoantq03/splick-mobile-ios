import Foundation
import SplickDomain

public struct CommentSubmissionAttachment: Sendable {
    public let kind: CommentAttachmentKind
    public let data: Data?
    public let remoteURL: URL?
    public let mimeType: String?
    public let fileName: String?

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
    }

    public init(kind: CommentAttachmentKind, remoteURL: URL, fileName: String? = nil) {
        self.kind = kind
        self.data = nil
        self.remoteURL = remoteURL
        self.mimeType = nil
        self.fileName = fileName
    }

    public var isRemoteOnly: Bool {
        remoteURL != nil && data == nil
    }
}
