import Foundation

/// One day in the user's streak calendar.
///
/// `photoCount == 0` means the user posted nothing on this date; `firstPhotoURL` will be `nil`.
public struct StreakDay: Identifiable, Equatable, Sendable {
    public let date: Date
    public let firstPhotoURL: URL?
    public let firstThumbnailURL: URL?
    public let photoCount: Int

    public var id: Date { date }
    public var hasPhoto: Bool { photoCount > 0 }

    public init(
        date: Date,
        firstPhotoURL: URL?,
        firstThumbnailURL: URL?,
        photoCount: Int
    ) {
        self.date = date
        self.firstPhotoURL = firstPhotoURL
        self.firstThumbnailURL = firstThumbnailURL
        self.photoCount = photoCount
    }
}

/// Summary of the user's posting streak.
public struct StreakSummary: Equatable, Sendable {
    /// Consecutive UTC days ending today with at least one IMAGE post. 0 means no active streak.
    public let currentStreak: Int
    /// Whether the user has already posted an IMAGE today (UTC).
    public let hasTodayPhoto: Bool

    public init(currentStreak: Int, hasTodayPhoto: Bool) {
        self.currentStreak = currentStreak
        self.hasTodayPhoto = hasTodayPhoto
    }
}
