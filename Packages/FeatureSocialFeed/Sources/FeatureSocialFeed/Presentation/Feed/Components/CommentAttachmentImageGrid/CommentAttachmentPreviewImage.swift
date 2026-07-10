import UIKit
import SplickDomain

enum CommentAttachmentUploadStatus: Equatable {
    case uploading
    case uploaded
    case failed(message: String)
}

struct CommentAttachmentPreviewImage: Identifiable, Equatable {
    let id: UUID
    let localPreview: UIImage?
    let remoteURL: URL?
    let uploadStatus: CommentAttachmentUploadStatus
    let progress: Double?
    let width: CGFloat?
    let height: CGFloat?
    let accessibilityLabel: String

    init(
        id: UUID,
        localPreview: UIImage?,
        remoteURL: URL? = nil,
        uploadStatus: CommentAttachmentUploadStatus,
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

extension CommentAttachment {
    var previewImageModel: CommentAttachmentPreviewImage? {
        guard kind == .image, url != nil else { return nil }
        return CommentAttachmentPreviewImage(
            id: id,
            localPreview: nil,
            remoteURL: url,
            uploadStatus: .uploaded,
            accessibilityLabel: fileName ?? "Ảnh đính kèm"
        )
    }
}
