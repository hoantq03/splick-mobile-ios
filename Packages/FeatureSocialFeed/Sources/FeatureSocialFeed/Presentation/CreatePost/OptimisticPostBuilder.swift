import Foundation
import UIKit
import SplickDomain

enum OptimisticPostBuilder {
    static func build(
        author: UserSummary,
        input: CreatePostInput,
        mediaDrafts: [ComposeMediaDraft],
        companions: [UserSummary]
    ) throws -> Post {
        let postId = UUID()
        let mediaDirectory = try makeMediaDirectory(for: postId)
        let mediaItems = try mediaDrafts.enumerated().map { index, draft in
            try makeMediaItem(
                postId: postId,
                draft: draft,
                index: index,
                directory: mediaDirectory
            )
        }

        guard let firstMediaItem = mediaItems.first else {
            throw OptimisticPostBuilderError.missingMedia
        }

        return Post(
            id: postId,
            author: author,
            imageURL: firstMediaItem.thumbnailURL ?? firstMediaItem.mediaURL,
            thumbnailURL: firstMediaItem.thumbnailURL,
            caption: input.caption,
            reactions: [],
            comments: [],
            groupId: input.groupId,
            createdAt: .now,
            mediaType: firstMediaItem.mediaType,
            videoURL: firstMediaItem.mediaType == .video ? firstMediaItem.mediaURL : nil,
            videoDurationSeconds: firstMediaItem.durationSeconds,
            mediaItems: mediaItems,
            companions: companions,
            feedKind: input.feedKind,
            checkInPlace: input.checkInPlace,
            billSplit: input.billSplit,
            viewCount: 0,
            viewers: [],
            audience: input.audience
        )
    }

    private static func makeMediaDirectory(for postId: UUID) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("splick-optimistic-posts", isDirectory: true)
            .appendingPathComponent(postId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func makeMediaItem(
        postId: UUID,
        draft: ComposeMediaDraft,
        index: Int,
        directory: URL
    ) throws -> PostMediaItem {
        let mediaExtension = fileExtension(for: draft.mimeType, mediaType: draft.mediaType)
        let mediaURL = directory.appendingPathComponent("media-\(index).\(mediaExtension)")
        try draft.data.write(to: mediaURL, options: .atomic)

        let thumbnailURL: URL?
        switch draft.mediaType {
        case .image:
            thumbnailURL = mediaURL
        case .video:
            if let previewImage = draft.previewImage,
               let thumbnailData = previewImage.jpegData(compressionQuality: 0.85) {
                let url = directory.appendingPathComponent("thumb-\(index).jpg")
                try thumbnailData.write(to: url, options: .atomic)
                thumbnailURL = url
            } else {
                thumbnailURL = nil
            }
        }

        return PostMediaItem(
            mediaURL: mediaURL,
            thumbnailURL: thumbnailURL,
            mediaType: draft.mediaType,
            durationSeconds: draft.videoDurationSeconds,
            sortOrder: index
        )
    }

    private static func fileExtension(for mimeType: String, mediaType: PostMediaType) -> String {
        switch mimeType.lowercased() {
        case "image/png":
            return "png"
        case "video/mp4":
            return "mp4"
        default:
            return mediaType == .video ? "mp4" : "jpg"
        }
    }
}

private enum OptimisticPostBuilderError: LocalizedError {
    case missingMedia

    var errorDescription: String? {
        switch self {
        case .missingMedia:
            return "Chọn ít nhất một ảnh hoặc video."
        }
    }
}
