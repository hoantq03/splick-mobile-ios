import Foundation
import SplickDomain

public struct PhotoAlbumFilters: Equatable, Sendable {
    public var authors: [UserSummary]
    public var groups: [Group]
    public var captionQuery: String
    public var feedKind: PostFeedKind?

    public init(
        authors: [UserSummary] = [],
        groups: [Group] = [],
        captionQuery: String = "",
        feedKind: PostFeedKind? = nil
    ) {
        self.authors = authors
        self.groups = groups
        self.captionQuery = captionQuery
        self.feedKind = feedKind
    }

    public var trimmedCaptionQuery: String {
        captionQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var apiCaptionQuery: String? {
        let trimmed = trimmedCaptionQuery
        guard trimmed.count >= 2 else { return nil }
        return trimmed
    }

    public var hasAnyFilter: Bool {
        !authors.isEmpty || !groups.isEmpty || apiCaptionQuery != nil || feedKind != nil
    }

    public mutating func clearAll() {
        authors = []
        groups = []
        captionQuery = ""
        feedKind = nil
    }
}
