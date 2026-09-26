import Foundation
import SplickDomain

enum PostEditHistoryChange: Equatable, Sendable {
    case original
    case caption
    case media
    case audience
    case companions
    case mixed
}

struct PostEditHistoryDiff: Equatable, Sendable {
    let isOriginal: Bool
    let captionChanged: Bool
    let mediaChanged: Bool
    let audienceChanged: Bool
    let companionsChanged: Bool
    let previousCaption: String?
    let nextCaption: String?
    let addedMedia: [PostMediaItem]
    let removedMedia: [PostMediaItem]
    let previousAudience: PostAudience?
    let nextAudience: PostAudience?
    let addedCompanions: [UserSummary]
    let removedCompanions: [UserSummary]
}

struct PostEditHistoryItem: Identifiable, Equatable, Sendable {
    var id: Int { version }
    let version: Int
    let editedAt: Date
    let caption: String?
    let mediaItems: [PostMediaItem]
    let audience: PostAudience?
    let companions: [UserSummary]?
    let isCurrent: Bool
    let change: PostEditHistoryChange
    let diff: PostEditHistoryDiff
}

enum PostEditHistoryTimeline {
    static func items(
        previousNewestFirst: [PostEditRevision],
        currentCaption: String?,
        currentMedia: [PostMediaItem],
        currentAt: Date,
        currentAudience: PostAudience? = nil,
        currentCompanions: [UserSummary]? = nil
    ) -> [PostEditHistoryItem] {
        let previousOldestFirst = previousNewestFirst.reversed()
        var snapshots = previousOldestFirst.map {
            Snapshot(
                editedAt: $0.editedAt,
                caption: $0.caption,
                mediaItems: $0.mediaItems,
                audience: $0.audience,
                companions: $0.companions,
                isCurrent: false
            )
        }
        snapshots.append(
            Snapshot(
                editedAt: currentAt,
                caption: currentCaption,
                mediaItems: currentMedia,
                audience: currentAudience,
                companions: currentCompanions,
                isCurrent: true
            )
        )

        return Array(snapshots.enumerated().map { index, snapshot in
            let diff = index == 0 ? originalDiff(snapshot) : Self.diff(from: snapshots[index - 1], to: snapshot)
            return PostEditHistoryItem(
                version: index + 1,
                editedAt: snapshot.editedAt,
                caption: snapshot.caption,
                mediaItems: snapshot.mediaItems,
                audience: snapshot.audience,
                companions: snapshot.companions,
                isCurrent: snapshot.isCurrent,
                change: changeKind(diff),
                diff: diff
            )
        }.reversed())
    }

    private struct Snapshot {
        let editedAt: Date
        let caption: String?
        let mediaItems: [PostMediaItem]
        let audience: PostAudience?
        let companions: [UserSummary]?
        let isCurrent: Bool
    }

    private static func originalDiff(_ snapshot: Snapshot) -> PostEditHistoryDiff {
        PostEditHistoryDiff(
            isOriginal: true,
            captionChanged: false,
            mediaChanged: false,
            audienceChanged: false,
            companionsChanged: false,
            previousCaption: nil,
            nextCaption: snapshot.caption,
            addedMedia: [],
            removedMedia: [],
            previousAudience: nil,
            nextAudience: snapshot.audience,
            addedCompanions: [],
            removedCompanions: []
        )
    }

    private static func diff(from previous: Snapshot, to next: Snapshot) -> PostEditHistoryDiff {
        let captionChanged = normalized(previous.caption) != normalized(next.caption)
        let previousIds = previous.mediaItems.map(\.id)
        let nextIds = next.mediaItems.map(\.id)
        let mediaChanged = previousIds != nextIds
        let previousCompanionIds = Set((previous.companions ?? []).map(\.id))
        let nextCompanionIds = Set((next.companions ?? []).map(\.id))
        return PostEditHistoryDiff(
            isOriginal: false,
            captionChanged: captionChanged,
            mediaChanged: mediaChanged,
            audienceChanged: previous.audience != nil && next.audience != nil && previous.audience != next.audience,
            companionsChanged: previous.companions != nil && next.companions != nil &&
                (previous.companions ?? []).map(\.id) != (next.companions ?? []).map(\.id),
            previousCaption: previous.caption,
            nextCaption: next.caption,
            addedMedia: next.mediaItems.filter { !previousIds.contains($0.id) },
            removedMedia: previous.mediaItems.filter { !nextIds.contains($0.id) },
            previousAudience: previous.audience,
            nextAudience: next.audience,
            addedCompanions: (next.companions ?? []).filter { !previousCompanionIds.contains($0.id) },
            removedCompanions: (previous.companions ?? []).filter { !nextCompanionIds.contains($0.id) }
        )
    }

    private static func changeKind(_ diff: PostEditHistoryDiff) -> PostEditHistoryChange {
        if diff.isOriginal { return .original }
        let flags = [diff.captionChanged, diff.mediaChanged, diff.audienceChanged, diff.companionsChanged]
        let count = flags.filter { $0 }.count
        if count > 1 { return .mixed }
        if diff.captionChanged { return .caption }
        if diff.mediaChanged { return .media }
        if diff.audienceChanged { return .audience }
        if diff.companionsChanged { return .companions }
        return .caption
    }

    private static func normalized(_ caption: String?) -> String {
        caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
