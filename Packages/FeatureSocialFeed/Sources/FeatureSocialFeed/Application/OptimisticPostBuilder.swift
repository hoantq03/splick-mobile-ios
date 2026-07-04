import Foundation
import UIKit
import SplickDomain

enum OptimisticPostBuilder {
    enum BuildError: LocalizedError {
        case mediaWriteFailed

        var errorDescription: String? {
            switch self {
            case .mediaWriteFailed:
                return "Không thể chuẩn bị media để đăng bài."
            }
        }
    }

    static func build(
        localPostId: UUID = UUID(),
        author: UserSummary,
        input: CreatePostInput,
        mediaDrafts: [ComposeMediaDraft],
        companions: [UserSummary]
    ) throws -> Post {
        let mediaItems = try writeMediaDrafts(mediaDrafts, postId: localPostId)
        let first = mediaItems.first
        let primaryType = first?.mediaType ?? .image
        let imageURL = first?.thumbnailURL ?? first?.mediaURL ?? placeholderURL

        return Post(
            id: localPostId,
            author: author,
            imageURL: imageURL,
            thumbnailURL: first?.thumbnailURL,
            caption: input.caption,
            reactions: [],
            comments: [],
            groupId: input.groupId,
            createdAt: .now,
            mediaType: primaryType,
            videoURL: primaryType == .video ? first?.mediaURL : nil,
            videoDurationSeconds: first?.durationSeconds,
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

    static func cleanupPendingMedia(postId: UUID) {
        let directory = pendingDirectory(for: postId)
        try? FileManager.default.removeItem(at: directory)
    }

    private static var placeholderURL: URL {
        URL(string: "https://placeholder.splick.local/pending-post")!
    }

    private static func pendingDirectory(for postId: UUID) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-posts/\(postId.uuidString)", isDirectory: true)
    }

    private static func writeMediaDrafts(
        _ drafts: [ComposeMediaDraft],
        postId: UUID
    ) throws -> [PostMediaItem] {
        let directory = pendingDirectory(for: postId)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return try drafts.enumerated().map { index, draft in
            let fileURL: URL
            switch draft.mediaType {
            case .image:
                let ext = draft.mimeType.contains("png") ? "png" : "jpg"
                fileURL = directory.appendingPathComponent("\(index).\(ext)")
                try draft.data.write(to: fileURL, options: .atomic)
            case .video:
                fileURL = directory.appendingPathComponent("\(index).mp4")
                try draft.data.write(to: fileURL, options: .atomic)
            }

            var thumbnailURL: URL?
            if let preview = draft.previewImage,
               let jpeg = preview.jpegData(compressionQuality: 0.85) {
                let thumbFile = directory.appendingPathComponent("\(index)-thumb.jpg")
                try jpeg.write(to: thumbFile, options: .atomic)
                thumbnailURL = thumbFile
            }

            let resolvedThumbnail = thumbnailURL ?? (draft.mediaType == .image ? fileURL : nil)
            return PostMediaItem(
                mediaURL: fileURL,
                thumbnailURL: resolvedThumbnail,
                mediaType: draft.mediaType,
                durationSeconds: draft.videoDurationSeconds,
                sortOrder: index
            )
        }
    }
}
