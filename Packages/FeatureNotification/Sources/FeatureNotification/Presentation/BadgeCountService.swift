import Foundation
import Common

@MainActor
public final class BadgeCountService: ObservableObject {
    @Published public private(set) var counts: TabBadgeCounts = .zero

    private let fetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol
    private let pollInterval: Duration
    private var pollingTask: Task<Void, Never>?

    public init(
        fetchBadgeCountsUseCase: FetchBadgeCountsUseCaseProtocol,
        pollInterval: Duration = .seconds(20)
    ) {
        self.fetchBadgeCountsUseCase = fetchBadgeCountsUseCase
        self.pollInterval = pollInterval
    }

    deinit {
        pollingTask?.cancel()
    }

    public func refresh() async {
        do {
            counts = try await fetchBadgeCountsUseCase.execute()
        } catch {
            Log.error(error, category: .notification)
        }
    }

    public func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                do {
                    try await Task.sleep(for: self.pollInterval)
                } catch {
                    break
                }
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
