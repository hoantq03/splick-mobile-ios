import SwiftUI
import Common
import DesignSystem
import SplickDomain

public typealias CommentAttachmentPreviewImage = InlineAttachmentPreviewImage
public typealias CommentAttachmentUploadStatus = InlineAttachmentUploadStatus
public typealias CommentAttachmentDraftStrip = AttachmentDraftStrip
public typealias CommentAttachmentImageGrid = InlineAttachmentImageGrid

public typealias CommentImageUploadHandler = ImageAttachmentUploadHandler

public extension EnvironmentValues {
    var commentImageUpload: ImageAttachmentUploadHandler? {
        get { imageAttachmentUpload }
        set { imageAttachmentUpload = newValue }
    }
}
