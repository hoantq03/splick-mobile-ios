import Foundation
import SplickDomain

enum DeleteStreakRisk {
    /// Warn whenever deleting would drop a live streak (1+ days).
    static let minimumStreakToWarn = 1

    static func utcDateString(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func hasImage(_ post: Post) -> Bool {
        post.mediaType == .image || post.mediaItems.contains { $0.mediaType == .image }
    }

    /// Returns the current streak length when deleting `post` would break it; otherwise `nil`.
    static func streakDaysIfDeleteBreaks(
        post: Post,
        knownPosts: [Post],
        fetchSummary: () async throws -> StreakSummary,
        fetchDayPhotos: (String) async throws -> [AlbumPhoto]
    ) async -> Int? {
        guard hasImage(post) else { return nil }
        let day = utcDateString(post.createdAt)
        guard day == utcDateString(Date()) else { return nil }

        let hasOtherLocalImageToday = knownPosts.contains { other in
            other.id != post.id
                && other.author.id == post.author.id
                && hasImage(other)
                && utcDateString(other.createdAt) == day
        }
        if hasOtherLocalImageToday { return nil }

        guard let summary = try? await fetchSummary(),
              summary.currentStreak >= minimumStreakToWarn else { return nil }
        guard let photos = try? await fetchDayPhotos(day) else { return nil }
        let postIds = Set(photos.map(\.postId))
        guard postIds.count == 1, postIds.contains(post.id) else { return nil }
        return summary.currentStreak
    }
}

struct PendingStreakDelete: Identifiable, Equatable {
    let postId: UUID
    let streakDays: Int
    var id: UUID { postId }
}
