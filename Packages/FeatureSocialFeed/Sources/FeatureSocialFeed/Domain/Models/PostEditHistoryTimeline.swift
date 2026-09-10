import Foundation
import SplickDomain

enum PostEditHistoryChange: Equatable, Sendable {
    case original
    case caption
    case media
    case captionAndMedia
}

struct PostEditHistoryItem: Identifiable, Equatable, Sendable {
    var id: Int { version }
    let version: Int
    let editedAt: Date
    let caption: String?
    let mediaItems: [PostMediaItem]
    let isCurrent: Bool
    let change: PostEditHistoryChange
}

enum PostEditHistoryTimeline {
    /// Builds newest-first cells. Version 1 is the oldest snapshot (original);
    /// the live post is the highest version.
    static func items(
        previousNewestFirst: [PostEditRevision],
        currentCaption: String?,
        currentMedia: [PostMediaItem],
        currentAt: Date
    ) -> [PostEditHistoryItem] {
        let previousOldestFirst = previousNewestFirst.reversed()
        var snapshots = previousOldestFirst.map {
            Snapshot(
                editedAt: $0.editedAt,
                caption: $0.caption,
                mediaItems: $0.mediaItems,
                isCurrent: false
            )
        }
        snapshots.append(
            Snapshot(
                editedAt: currentAt,
                caption: currentCaption,
                mediaItems: currentMedia,
                isCurrent: true
            )
        )

        return Array(snapshots.enumerated().map { index, snapshot in
            let change: PostEditHistoryChange
            if index == 0 {
                change = .original
            } else {
                change = diff(from: snapshots[index - 1], to: snapshot)
            }
            return PostEditHistoryItem(
                version: index + 1,
                editedAt: snapshot.editedAt,
                caption: snapshot.caption,
                mediaItems: snapshot.mediaItems,
                isCurrent: snapshot.isCurrent,
                change: change
            )
        }.reversed())
    }

    private struct Snapshot {
        let editedAt: Date
        let caption: String?
        let mediaItems: [PostMediaItem]
        let isCurrent: Bool
    }

    private static func diff(from previous: Snapshot, to next: Snapshot) -> PostEditHistoryChange {
        let captionChanged = normalized(previous.caption) != normalized(next.caption)
        let mediaChanged = previous.mediaItems.map(\.id) != next.mediaItems.map(\.id)
        switch (captionChanged, mediaChanged) {
        case (true, true): return .captionAndMedia
        case (true, false): return .caption
        case (false, true): return .media
        case (false, false): return .caption
        }
    }

    private static func normalized(_ caption: String?) -> String {
        caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
