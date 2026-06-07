import Foundation

public enum FeedContentSegment: String, CaseIterable, Identifiable, Sendable {
    case feed
    case album

    public var id: String { rawValue }
}
