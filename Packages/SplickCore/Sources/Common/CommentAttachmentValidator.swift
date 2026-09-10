import Foundation
import SplickDomain

public enum CommentAttachmentValidator {
    public static let maxImages = AppConstants.Comments.maxImagesPerComment
    public static let maxFiles = 10
    public static let maxVideos = AppConstants.Comments.maxVideosPerComment
    public static let maxGifs = AppConstants.Stickers.maxGifsPerComment
    public static let maxFileTotalBytes = 10 * 1024 * 1024
    public static let maxVideoTotalBytes = 100 * 1024 * 1024

    public static func validate(_ attachments: [CommentAttachment]) -> String? {
        let images = attachments.filter { $0.kind == .image }
        let files = attachments.filter { $0.kind == .file }
        let videos = attachments.filter { $0.kind == .video }
        let gifs = attachments.filter { $0.kind == .gif }

        if images.count > maxImages {
            return "Tối đa \(maxImages) ảnh mỗi bình luận."
        }
        if files.count > maxFiles {
            return "Tối đa \(maxFiles) tệp mỗi bình luận."
        }
        if videos.count > maxVideos {
            return "Tối đa \(maxVideos) video mỗi bình luận."
        }
        if gifs.count > maxGifs {
            return "Tối đa \(maxGifs) GIF mỗi bình luận."
        }

        let fileBytes = files.reduce(0) { $0 + $1.sizeBytes }
        if fileBytes > maxFileTotalBytes {
            return "Tổng dung lượng tệp tối đa 10MB."
        }

        let videoBytes = videos.reduce(0) { $0 + $1.sizeBytes }
        if videoBytes > maxVideoTotalBytes {
            return "Tổng dung lượng video tối đa 100MB."
        }

        return nil
    }

    public static func canAdd(
        _ attachment: CommentAttachment,
        to existing: [CommentAttachment]
    ) -> String? {
        validate(existing + [attachment])
    }

    public static func previewModels(from submissions: [CommentSubmissionAttachment]) -> [CommentAttachment] {
        submissions.map {
            CommentAttachment(
                kind: $0.kind,
                fileName: $0.fileName,
                sizeBytes: $0.uploadedSizeBytes ?? $0.data?.count ?? 0
            )
        }
    }
}
