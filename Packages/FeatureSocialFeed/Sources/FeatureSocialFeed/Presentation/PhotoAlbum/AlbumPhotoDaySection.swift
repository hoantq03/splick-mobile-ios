import Foundation
import SplickDomain

struct AlbumPhotoDaySection: Identifiable, Equatable {
    /// Stable key `yyyy-MM-dd` for SwiftUI identity.
    let id: String
    let day: Date
    let title: String
    let photos: [AlbumPhoto]
}

enum AlbumPhotoSectionBuilder {
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let sameYearTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let fullTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    static func daySections(from photos: [AlbumPhoto], calendar: Calendar = .current) -> [AlbumPhotoDaySection] {
        guard !photos.isEmpty else { return [] }

        var grouped: [Date: [AlbumPhoto]] = [:]
        grouped.reserveCapacity(min(photos.count, 32))

        for photo in photos {
            let day = calendar.startOfDay(for: photo.createdAt)
            grouped[day, default: []].append(photo)
        }

        return grouped.keys
            .sorted(by: >)
            .map { day in
                let dayPhotos = grouped[day] ?? []
                return AlbumPhotoDaySection(
                    id: dayKeyFormatter.string(from: day),
                    day: day,
                    title: sectionTitle(for: day, calendar: calendar),
                    photos: dayPhotos
                )
            }
    }

    private static func sectionTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) {
            return "Hôm nay"
        }
        if calendar.isDateInYesterday(day) {
            return "Hôm qua"
        }
        if calendar.isDate(day, equalTo: .now, toGranularity: .year) {
            return sameYearTitleFormatter.string(from: day)
        }
        return fullTitleFormatter.string(from: day)
    }
}
