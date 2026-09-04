import Foundation
import Common

@MainActor
public final class BadgeCountService: ObservableObject {
    @Published public private(set) var counts: TabBadgeCounts = .zero

    private let fetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol
    private var pollingTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private let pollInterval: Duration
    /// Skip redundant network fetches shortly after startup `apply` or a successful refresh.
    private let minRefreshInterval: TimeInterval = 25
    private var lastFreshAt: Date?

    public init(
        fetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol,
        pollInterval: Duration = .seconds(30)
    ) {
        self.fetchBadgeCountsUseCase = fetchBadgeCountsUseCase
        self.pollInterval = pollInterval
    }

    deinit {
        pollingTask?.cancel()
    }

    /// - Parameter force: When true, bypasses the freshness window (use after mutations).
    public func refresh(force: Bool = false) async {
        if !force, let lastFreshAt, Date().timeIntervalSince(lastFreshAt) < minRefreshInterval {
            return
        }

        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    public func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }
            // Defer the first poll — startup / scene activation already hydrate badges.
            while !Task.isCancelled {
                try? await Task.sleep(for: self.pollInterval)
                guard !Task.isCancelled else { return }
                await self.refresh()
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func performRefresh() async {
        do {
            counts = try await fetchBadgeCountsUseCase.execute()
            lastFreshAt = Date()
        } catch {
            Log.error(error, category: .notification, metadata: ["action": "refreshBadgeCounts"])
        }
    }

    public func apply(_ newCounts: TabBadgeCounts) {
        counts = newCounts
        lastFreshAt = Date()
    }

    public func clearUnseenInboxBadges() {
        counts = counts.clearingUnseenInboxBadges()
        lastFreshAt = Date()
    }
}
