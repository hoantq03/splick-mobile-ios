import Foundation
import SplickDomain

public struct CommentSubmissionAttachment: Sendable {
    public let kind: CommentAttachmentKind
    public let data: Data
    public let mimeType: String
    public let fileName: String?

    public init(
        kind: CommentAttachmentKind,
        data: Data,
        mimeType: String,
        fileName: String?
    ) {
        self.kind = kind
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
    }
}
