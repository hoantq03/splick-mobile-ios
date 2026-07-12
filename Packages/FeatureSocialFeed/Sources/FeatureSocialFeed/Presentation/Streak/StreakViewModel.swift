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
    @Published private(set) var hasReachedOldestMonth = false

    private let fetchStreakUseCase: FetchStreakUseCaseProtocol
    private let onStreakUpdated: ((StreakSummary) async -> Void)?
    private let calendar = Calendar.current
    private var loadTask: Task<Void, Never>?
    /// Current month only on first open; older months load via `loadOlderMonthIfNeeded`.
    private let initialMonthCount = 1
    private static let maxMonthsInPast = 24

    public init(
        fetchStreakUseCase: FetchStreakUseCaseProtocol,
        onStreakUpdated: ((StreakSummary) async -> Void)? = nil
    ) {
        self.fetchStreakUseCase = fetchStreakUseCase
        self.onStreakUpdated = onStreakUpdated
    }

    public func applyStartupSummary(currentStreak: Int, hasTodayPhoto: Bool) {
        self.currentStreak = currentStreak
        self.hasTodayPhoto = hasTodayPhoto
    }

    var anchorMonthID: String {
        let components = calendar.dateComponents([.year, .month], from: Date())
        let year = components.year ?? 2026
        let month = components.month ?? 1
        return monthSectionID(year: year, month: month)
    }

    func loadIfNeeded() async {
        guard monthSections.isEmpty else { return }
        // Single-flight: pager remounts must not cancel+restart calendar fetches.
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await performRefresh() }
        loadTask = task
        await task.value
        if loadTask == task {
            loadTask = nil
        }
    }

    func refresh() async {
        loadTask?.cancel()
        let task = Task { await performRefresh() }
        loadTask = task
        await task.value
        if loadTask == task {
            loadTask = nil
        }
    }

    func loadOlderMonthIfNeeded(for section: StreakMonthSection) async -> Bool {
        guard section.id == monthSections.first?.id, !isLoadingOlderMonths, !hasReachedOldestMonth else {
            return false
        }

        guard let previous = previousMonth(year: section.year, month: section.month) else {
            hasReachedOldestMonth = true
            return false
        }

        guard isMonthAllowed(year: previous.year, month: previous.month) else {
            hasReachedOldestMonth = true
            return false
        }

        let sectionID = monthSectionID(year: previous.year, month: previous.month)
        guard !monthSections.contains(where: { $0.id == sectionID }) else {
            return false
        }

        isLoadingOlderMonths = true
        defer { isLoadingOlderMonths = false }

        do {
            let days = try await fetchStreakUseCase.fetchCalendar(
                year: previous.year,
                month: previous.month
            )
            guard !Task.isCancelled else { return false }
            let olderSection = StreakMonthSection(
                year: previous.year,
                month: previous.month,
                days: days
            )
            monthSections.insert(olderSection, at: 0)
            if let nextOlder = previousMonth(year: olderSection.year, month: olderSection.month),
               !isMonthAllowed(year: nextOlder.year, month: nextOlder.month) {
                hasReachedOldestMonth = true
            }
            return true
        } catch {
            if !error.isRequestCancellation {
                Log.error(error, category: .feed)
                if isStreakMonthOutOfRange(error) {
                    hasReachedOldestMonth = true
                }
            }
            return false
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
            hasReachedOldestMonth = false
            monthSections = months.sorted { $0.monthDate < $1.monthDate }
            state = .loaded(monthSections)
            await onStreakUpdated?(summary)
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
        var months: [(year: Int, month: Int)] = []
        months.reserveCapacity(count)
        var cursor = end
        for _ in 0..<count {
            months.append(cursor)
            guard let previous = previousMonth(year: cursor.year, month: cursor.month) else { break }
            cursor = previous
        }

        return try await withThrowingTaskGroup(of: StreakMonthSection.self) { group in
            for (year, month) in months {
                group.addTask { [fetchStreakUseCase] in
                    let days = try await fetchStreakUseCase.fetchCalendar(year: year, month: month)
                    return StreakMonthSection(year: year, month: month, days: days)
                }
            }

            var sections: [StreakMonthSection] = []
            sections.reserveCapacity(months.count)
            for try await section in group {
                sections.append(section)
            }
            return sections.sorted { $0.monthDate < $1.monthDate }
        }
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

    private func oldestAllowedYearMonth() -> (year: Int, month: Int) {
        guard let date = calendar.date(byAdding: .month, value: -Self.maxMonthsInPast, to: Date()) else {
            return (2020, 1)
        }
        let components = calendar.dateComponents([.year, .month], from: date)
        return (components.year ?? 2020, components.month ?? 1)
    }

    private func isMonthAllowed(year: Int, month: Int) -> Bool {
        let oldest = oldestAllowedYearMonth()
        if year < oldest.year { return false }
        if year == oldest.year, month < oldest.month { return false }
        return true
    }

    private func isStreakMonthOutOfRange(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("24 months") || message.contains("last 24")
    }
}
