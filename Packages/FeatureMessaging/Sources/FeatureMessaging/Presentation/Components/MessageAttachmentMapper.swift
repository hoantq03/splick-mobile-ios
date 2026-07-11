import Foundation
import Common
import SplickDomain

enum MessageAttachmentMapper {
    static func messageImage(from submission: CommentSubmissionAttachment) -> MessageImageAttachment? {
        guard submission.kind == .image,
              let mediaId = submission.uploadedMediaId,
              let url = submission.remoteURL else {
            return nil
        }
        return MessageImageAttachment(
            mediaId: mediaId,
            url: url,
            thumbnailURL: submission.uploadedThumbnailURL
        )
    }
}

enum MessageImageLimits {
    static let maxImages = AppConstants.Comments.maxImagesPerComment
}
