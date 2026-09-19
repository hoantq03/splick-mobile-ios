import Foundation
import SplickDomain

struct StreakDeleteWarning: Equatable {
    let streakDays: Int
    let isToday: Bool
}

enum DeleteStreakRisk {
    /// Warn whenever deleting would drop a live streak (1+ days).
    static let minimumStreakToWarn = 1

    static func utcDateString(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
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
        now: Date = Date(),
        timeZone: TimeZone = .current,
        fetchSummary: () async throws -> StreakSummary,
        fetchDayPhotos: (String) async throws -> [AlbumPhoto]
    ) async -> StreakDeleteWarning? {
        guard hasImage(post) else { return nil }
        let day = utcDateString(post.createdAt, timeZone: timeZone)
        let today = utcDateString(now, timeZone: timeZone)
        let isToday = day == today

        let hasOtherLocalImageSameDay = knownPosts.contains { other in
            other.id != post.id
                && other.author.id == post.author.id
                && hasImage(other)
                && utcDateString(other.createdAt, timeZone: timeZone) == day
        }
        if hasOtherLocalImageSameDay { return nil }

        guard let summary = try? await fetchSummary(),
              summary.currentStreak >= minimumStreakToWarn else { return nil }
        guard isInLiveStreakWindow(
            day: day,
            today: today,
            currentStreak: summary.currentStreak,
            hasTodayPhoto: summary.hasTodayPhoto || isToday,
            timeZone: timeZone
        ) else { return nil }
        guard let photos = try? await fetchDayPhotos(day) else { return nil }
        let postIds = Set(photos.map(\.postId))
        guard postIds.count == 1, postIds.contains(post.id) else { return nil }
        return StreakDeleteWarning(streakDays: summary.currentStreak, isToday: isToday)
    }

    static func isInLiveStreakWindow(
        day: String,
        today: String,
        currentStreak: Int,
        hasTodayPhoto: Bool,
        timeZone: TimeZone = .current
    ) -> Bool {
        guard currentStreak >= minimumStreakToWarn,
              let dayDate = parseDay(day, timeZone: timeZone),
              let todayDate = parseDay(today, timeZone: timeZone) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let newest: Date
        if day == today || hasTodayPhoto {
            newest = todayDate
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayDate) {
            newest = yesterday
        } else {
            return false
        }
        guard let oldest = calendar.date(
            byAdding: .day,
            value: -(currentStreak - 1),
            to: newest
        ) else { return false }
        return dayDate >= oldest && dayDate <= newest
    }

    private static func parseDay(_ value: String, timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

struct PendingStreakDelete: Identifiable, Equatable {
    let postId: UUID
    let streakDays: Int
    let isToday: Bool
    var id: UUID { postId }

    init(postId: UUID, warning: StreakDeleteWarning) {
        self.postId = postId
        self.streakDays = warning.streakDays
        self.isToday = warning.isToday
    }
}
