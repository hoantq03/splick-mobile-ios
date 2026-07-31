import Foundation
import os.signpost

/// Instruments signposts for feed scroll / load / video profiling.
enum FeedSignposts {
    static let log = OSLog(subsystem: "com.splick.feed", category: "Performance")

    static func beginFeedLoad(pullToRefresh: Bool) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(
            .begin,
            log: log,
            name: "FeedLoad",
            signpostID: id,
            "pullToRefresh=%{public}d",
            pullToRefresh ? 1 : 0
        )
        return id
    }

    static func endFeedLoad(_ id: OSSignpostID, count: Int) {
        os_signpost(.end, log: log, name: "FeedLoad", signpostID: id, "count=%{public}d", count)
    }

    static func beginFeedMerge() -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "FeedMerge", signpostID: id)
        return id
    }

    static func endFeedMerge(_ id: OSSignpostID) {
        os_signpost(.end, log: log, name: "FeedMerge", signpostID: id)
    }

    static func videoPlayerCreate() {
        os_signpost(.event, log: log, name: "VideoPlayerCreate")
    }

    static func videoPlayerAcquire(postId: UUID) {
        os_signpost(
            .event,
            log: log,
            name: "VideoPlayerAcquire",
            "postId=%{public}s",
            postId.uuidString
        )
    }

    static func videoPlayerRelease() {
        os_signpost(.event, log: log, name: "VideoPlayerRelease")
    }

    static func beginPostCardBody(postId: UUID) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(
            .begin,
            log: log,
            name: "PostCardBody",
            signpostID: id,
            "postId=%{public}s",
            postId.uuidString
        )
        return id
    }

    static func endPostCardBody(_ id: OSSignpostID) {
        os_signpost(.end, log: log, name: "PostCardBody", signpostID: id)
    }
}
