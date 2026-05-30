import Foundation
import SplickDomain

public struct PhotoAlbumFilters: Equatable, Sendable {
    public var author: UserSummary?
    public var group: Group?
    public var captionQuery: String = ""

    public init(
        author: UserSummary? = nil,
        group: Group? = nil,
        captionQuery: String = ""
    ) {
        self.author = author
        self.group = group
        self.captionQuery = captionQuery
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
        author != nil || group != nil || apiCaptionQuery != nil
    }

    public mutating func clearAll() {
        author = nil
        group = nil
        captionQuery = ""
    }
}
