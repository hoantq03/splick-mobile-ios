import Foundation
import Common

@MainActor
public final class BadgeCountService: ObservableObject {
    @Published public private(set) var counts: TabBadgeCounts = .zero

    private let fetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol
    private var pollingTask: Task<Void, Never>?
    private let pollInterval: Duration

    public init(
        fetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol,
        pollInterval: Duration = .seconds(30)
    ) {
        self.fetchBadgeCountsUseCase = fetchBadgeCountsUseCase
        self.pollInterval = pollInterval
    }

    public func refresh() async {
        do {
            counts = try await fetchBadgeCountsUseCase.execute()
        } catch {
            Log.error(error, category: .notification, metadata: ["action": "refreshBadgeCounts"])
        }
    }

    public func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
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

    public func apply(_ newCounts: TabBadgeCounts) {
        counts = newCounts
    }
}
