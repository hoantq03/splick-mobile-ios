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
    public let isAnimated: Bool
    public let accessibilityLabel: String

    public init(
        id: UUID,
        localPreview: UIImage?,
        remoteURL: URL? = nil,
        uploadStatus: InlineAttachmentUploadStatus,
        progress: Double? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        isAnimated: Bool = false,
        accessibilityLabel: String = "Ảnh đính kèm"
    ) {
        self.id = id
        self.localPreview = localPreview
        self.remoteURL = remoteURL
        self.uploadStatus = uploadStatus
        self.progress = progress
        self.width = width
        self.height = height
        self.isAnimated = isAnimated
        self.accessibilityLabel = accessibilityLabel
    }
}

public extension CommentAttachment {
    var inlinePreviewImage: InlineAttachmentPreviewImage? {
        inlinePreviewImage(isPending: false)
    }

    /// Builds a grid preview; when `isPending`, shows the frame immediately (even without URL)
    /// and an uploading overlay until the comment is confirmed.
    func inlinePreviewImage(isPending: Bool) -> InlineAttachmentPreviewImage? {
        guard kind == .image else { return nil }
        guard url != nil || isPending else { return nil }
        return InlineAttachmentPreviewImage(
            id: id,
            localPreview: nil,
            remoteURL: url ?? thumbnailURL,
            uploadStatus: isPending ? .uploading : .uploaded,
            accessibilityLabel: fileName ?? "Ảnh đính kèm"
        )
    }
}

public extension MessageImageAttachment {
    var inlinePreviewImage: InlineAttachmentPreviewImage {
        let animated = url.isLikelyAnimatedImage
        return InlineAttachmentPreviewImage(
            id: mediaId ?? UUID(),
            localPreview: nil,
            remoteURL: animated ? url : (thumbnailURL ?? url),
            uploadStatus: .uploaded,
            isAnimated: animated,
            accessibilityLabel: animated ? "GIF" : "Ảnh đính kèm"
        )
    }
}
