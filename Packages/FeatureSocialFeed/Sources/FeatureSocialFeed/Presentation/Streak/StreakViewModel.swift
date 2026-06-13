import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class StreakViewModel: ObservableObject {
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var hasTodayPhoto: Bool = false
    @Published private(set) var monthSections: [StreakMonthSection] = []
    @Published private(set) var state: LoadingState<[StreakMonthSection]> = .idle
    @Published var selectedDay: StreakDay?
    @Published private(set) var selectedDayPhotos: [AlbumPhoto] = []
    @Published private(set) var isDayPhotosLoading = false
    @Published private(set) var isLoadingOlderMonths = false

    private let fetchStreakUseCase: FetchStreakUseCaseProtocol
    private let calendar = Calendar.current
    private var loadTask: Task<Void, Never>?
    private let initialMonthCount = 4

    public init(fetchStreakUseCase: FetchStreakUseCaseProtocol) {
        self.fetchStreakUseCase = fetchStreakUseCase
    }

    var anchorMonthID: String {
        let components = calendar.dateComponents([.year, .month], from: Date())
        let year = components.year ?? 2026
        let month = components.month ?? 1
        return monthSectionID(year: year, month: month)
    }

    func loadIfNeeded() async {
        guard monthSections.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        loadTask?.cancel()
        let task = Task { await performRefresh() }
        loadTask = task
        await task.value
    }

    func loadOlderMonthIfNeeded(for section: StreakMonthSection) async {
        guard section.id == monthSections.first?.id, !isLoadingOlderMonths else { return }
        isLoadingOlderMonths = true
        defer { isLoadingOlderMonths = false }

        guard let previous = previousMonth(year: section.year, month: section.month) else { return }
        let sectionID = monthSectionID(year: previous.year, month: previous.month)
        guard !monthSections.contains(where: { $0.id == sectionID }) else { return }

        do {
            let days = try await fetchStreakUseCase.fetchCalendar(
                year: previous.year,
                month: previous.month
            )
            guard !Task.isCancelled else { return }
            let olderSection = StreakMonthSection(
                year: previous.year,
                month: previous.month,
                days: days
            )
            monthSections.insert(olderSection, at: 0)
        } catch {
            if !error.isRequestCancellation {
                Log.error(error, category: .feed)
            }
        }
    }

    func selectDay(_ day: StreakDay) {
        guard day.hasPhoto else { return }
        selectedDay = day
        Task { await loadDayPhotos(day) }
    }

    func dismissDayDetail() {
        selectedDay = nil
        selectedDayPhotos = []
    }

    private func performRefresh() async {
        if monthSections.isEmpty {
            state = .loading
        }

        do {
            async let summaryResult = fetchStreakUseCase.fetchSummary()
            let ending = currentYearMonth()
            let months = try await loadMonthRange(endingAt: ending, count: initialMonthCount)
            let summary = try await summaryResult
            guard !Task.isCancelled else { return }

            currentStreak = summary.currentStreak
            hasTodayPhoto = summary.hasTodayPhoto
            monthSections = months.sorted { $0.monthDate < $1.monthDate }
            state = .loaded(monthSections)
        } catch {
            guard !Task.isCancelled else { return }
            if error.isRequestCancellation { return }
            Log.error(error, category: .feed)
            if monthSections.isEmpty {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func loadMonthRange(endingAt end: (year: Int, month: Int), count: Int) async throws -> [StreakMonthSection] {
        var cursor = end
        var sections: [StreakMonthSection] = []
        sections.reserveCapacity(count)

        for _ in 0..<count {
            let days = try await fetchStreakUseCase.fetchCalendar(year: cursor.year, month: cursor.month)
            sections.append(StreakMonthSection(year: cursor.year, month: cursor.month, days: days))
            guard let previous = previousMonth(year: cursor.year, month: cursor.month) else { break }
            cursor = previous
        }

        return sections
    }

    private func loadDayPhotos(_ day: StreakDay) async {
        isDayPhotosLoading = true
        defer { isDayPhotosLoading = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: day.date)

        do {
            let photos = try await fetchStreakUseCase.fetchDayPhotos(date: dateString)
            guard !Task.isCancelled else { return }
            selectedDayPhotos = photos
        } catch {
            if !error.isRequestCancellation {
                Log.error(error, category: .feed)
            }
        }
    }

    private func currentYearMonth() -> (year: Int, month: Int) {
        let components = calendar.dateComponents([.year, .month], from: Date())
        return (components.year ?? 2026, components.month ?? 1)
    }

    private func previousMonth(year: Int, month: Int) -> (year: Int, month: Int)? {
        var components = DateComponents()
        components.year = year
        components.month = month - 1
        guard let date = calendar.date(from: components) else { return nil }
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let y = parts.year, let m = parts.month else { return nil }
        return (y, m)
    }

    private func monthSectionID(year: Int, month: Int) -> String {
        "\(year)-\(String(format: "%02d", month))"
    }
}
