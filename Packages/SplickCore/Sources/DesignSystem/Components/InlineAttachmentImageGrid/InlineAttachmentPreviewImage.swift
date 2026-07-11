import UIKit
import SplickDomain

public enum InlineAttachmentUploadStatus: Equatable {
    case uploading
    case uploaded
    case failed(message: String)
}

public struct InlineAttachmentPreviewImage: Identifiable, Equatable {
    public let id: UUID
    public let localPreview: UIImage?
    public let remoteURL: URL?
    public let uploadStatus: InlineAttachmentUploadStatus
    public let progress: Double?
    public let width: CGFloat?
    public let height: CGFloat?
    public let accessibilityLabel: String

    public init(
        id: UUID,
        localPreview: UIImage?,
        remoteURL: URL? = nil,
        uploadStatus: InlineAttachmentUploadStatus,
        progress: Double? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        accessibilityLabel: String = "Ảnh đính kèm"
    ) {
        self.id = id
        self.localPreview = localPreview
        self.remoteURL = remoteURL
        self.uploadStatus = uploadStatus
        self.progress = progress
        self.width = width
        self.height = height
        self.accessibilityLabel = accessibilityLabel
    }
}

public extension CommentAttachment {
    var inlinePreviewImage: InlineAttachmentPreviewImage? {
        guard kind == .image, url != nil else { return nil }
        return InlineAttachmentPreviewImage(
            id: id,
            localPreview: nil,
            remoteURL: url,
            uploadStatus: .uploaded,
            accessibilityLabel: fileName ?? "Ảnh đính kèm"
        )
    }
}

public extension MessageImageAttachment {
    var inlinePreviewImage: InlineAttachmentPreviewImage {
        InlineAttachmentPreviewImage(
            id: mediaId ?? UUID(),
            localPreview: nil,
            remoteURL: thumbnailURL ?? url,
            uploadStatus: .uploaded,
            accessibilityLabel: "Ảnh đính kèm"
        )
    }
}
